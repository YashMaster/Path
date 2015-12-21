#lift - is one of many 'sudo for Windows' implementations, but it is the best one. because we deserve nice things too.

#Important Note: 
#	-This is based off of @lukesampson's implementation in psutils. 
#	-Check out the original project here: https://github.com/lukesampson/psutils

#TODO
#	-Prevent anyone from using the pipe but the parent process
#		This could always done by using some kind of encryption. However that feels overengineered and this entire implementation is already insecure, so i's not worth it.
#	-Launch powershell twice IMMEDIATELY. This is basically what we do today, 
#		but we only have to launch the second powershell once instead of once per command.
#	-HWND security :(
#	-Add grace period feature

#Knwon Bugs
#	-Calling lift from an already-elevated window is a huge waste of life. Perf hit for no reason. 
#	-Calling lift from within a script will not reprompt for UAC...
#	-Std in/out/error redirection and piping don't work at all...
#	-Cannot ctrl+C out of it?

$DebugOn = $true
$GracePeriod = 1000 * 60 * 15 #15 minute grace period by default. 
$Source = @"
using System;
using System.IO;
using System.IO.Pipes;
using System.Threading;
using System.Threading.Tasks;

public static class Pipes
{
	public static bool ListenForConnection(NamedPipeServerStream pipe, int TimeOut = 3000)
	{
		var asyncResult = pipe.BeginWaitForConnection(null, null);
		if (asyncResult.AsyncWaitHandle.WaitOne(TimeOut))
		{
			pipe.EndWaitForConnection(asyncResult);
			return true;
		}
		return false;
	}
}
"@
if (-not ([System.Management.Automation.PSTypeName]'Pipes').Type) { Add-Type -TypeDefinition $Source -Language CSharp }

if (!$args) { "usage: lift <cmd...>"; exit 1 }

function is_admin { return ([System.Security.Principal.WindowsIdentity]::GetCurrent().UserClaims | ? { $_.Value -eq 'S-1-5-32-544'}) }
if (!(is_admin)) { [console]::error.writeline("lift: you must be an administrator to run lift"); exit 1 }

function write_msg($pipe, $msg) { 
	$json = ConvertTo-Json -Compress $msg
	$sw = New-Object System.IO.StreamWriter($pipe)
	$sw.WriteLine($json)
	$sw.Flush()
}

function read_msg($pipe) { 
	if ($DebugOn) { Write-Host "before read" }
	$sr = New-Object System.IO.StreamReader($pipe)
	$json = $sr.ReadLine()
	if ($json -eq $null -or $json.Length -eq 0) { if ($DebugOn) { Write-Host "read_msg: no message content" }; return "" }
	$msg = ConvertFrom-Json $json
	if ($DebugOn) { Write-Host ("after read: " + (ConvertTo-Json $msg)) }
	$msg
}

#Returns an open pipe. Closes a pipe if an open one is passed.
#Fun note: to list all pipes use: get-childitem "\\.\pipe\"
function get_pipe($pipe, $pipe_name) {
	if($pipe -ne $null) { $pipe.Dispose(); }
	$pipeSecurity = New-Object IO.Pipes.PipeSecurity
	$pipeSecurity.AddAccessRule((New-Object IO.Pipes.PipeAccessRule("Everyone", [IO.Pipes.PipeAccessRights]::FullControl, 0)))
	$pipe = New-Object IO.Pipes.NamedPipeServerStream($pipe_name, [IO.Pipes.PipeDirection]::InOut, 1, [IO.Pipes.PipeTransmissionMode]::Message, 
		[IO.Pipes.PipeOptions]::Asynchronous, [Pipes]::BuffSize, [Pipes]::BuffSize, $pipeSecurity, 0, [IO.Pipes.PipeAccessRights]::ChangePermissions)
	$pipe
}

function server($parent_pid, $pipe_name, $dir) {
	$src = '
	using System.Runtime.InteropServices;
	public class Kernel {
		[DllImport("kernel32.dll", SetLastError = true)]
		public static extern bool AllocConsole();
		[DllImport("kernel32.dll", SetLastError = true)]
		public static extern bool AttachConsole(uint dwProcessId);
		[DllImport("kernel32.dll", SetLastError = true, ExactSpelling = true)]
		public static extern bool FreeConsole();
	}'
	$kernel = add-type $src -passthru
	
	$pipe = $null
	while ($true) {
		$pipe = get_pipe $pipe $pipe_name
		$ret = [Pipes]::ListenForConnection($pipe);
		if ((Get-Process | ? { $_.Id -eq $parent_pid -and $_.Name -eq "powershell" }) -eq $null) { break }
		if (-not $ret) { if ($DebugOn) { Write-Host "connection was no good..." }; continue }
		
		$msg = read_msg $pipe
		if ($msg.cmd.Length -le 0) { if ($DebugOn) { Write-Host "cmd length <= 0" }; continue }
		if ($msg.cmd -eq "exit") { break }

		if (-not $DebugOn){ $kernel::freeconsole(); $kernel::attachconsole($parent_pid) }
		
		#$cmd = "& $($msg.cmd)"
		#Invoke-Expression $cmd
		
		$p = New-Object diagnostics.process; $start = $p.startinfo
		$start.filename = "powershell.exe"
		$start.arguments = "-noprofile $($msg.cmd)`nexit `$lastexitcode"
		$start.useshellexecute = $false
		$start.workingdirectory = $msg.dir
		$p.start()
		$p.waitforexit()
		if (-not $DebugOn) { $kernel::freeconsole() }
		
		$props = @{ 'pid'	=	$pid;
					'dir'	=	(Convert-Path $pwd);
					'cmd'	=	$cmd; 
					'ret'	=	$p.exitcode; }
		$msg = New-Object -TypeName PSObject -Prop $props
		write_msg $pipe $msg
	}

	$pipe.Dispose()
} 

function try_spawn_server($pipe_name) {
	if (Test-Path "\\.\pipe\$pipe_name") { return } 
	if ($DebugOn) { Write-Host "Pipe doesn't exist, gotta create it" }

	$p = New-Object diagnostics.process; $start = $p.startinfo
	$start.filename = "powershell.exe"
	$start.arguments = "-noprofile & '$pscommandpath' -do $pid $pipe_name`nexit `$lastexitcode"
	$start.verb = 'runas'
	$start.windowstyle = 'hidden'
	if ($DebugOn) { $start.windowstyle = 'normal' }

	try 	{ $null = $p.start() }
	catch 	{ exit 1 } #user didn't provide consent
}

function client($pipe_name, $cmd) {
	$props = @{ 'pid'	=	$pid;
				'dir'	=	(Convert-Path $pwd);
				'cmd'	=	$cmd; 
				'ret'	=	0; }
	$msg = New-Object -TypeName PSObject -Prop $props
	
	$pipe = New-Object System.IO.Pipes.NamedPipeClientStream($pipe_name);
	$pipe.Connect();
	write_msg $pipe $msg
	$response = read_msg $pipe
	$pipe.Dispose();
	$response.ret
}

function serialize($a, $escape) {
	if ($a -is [string] -and $a -match '\s') { return "'$a'" }
	if ($a -is [array]) { return $a | % { (serialize $_ $escape) -join ', ' } }
	if ($escape) { return $a -replace '[>&]', '`$0' }
	return $a
}

if($args[0] -eq '-do') {
	$null, $parent_pid, $parent_pipe_name, $dir = $args
	$exit_code = server $parent_pid $parent_pipe_name $dir
	exit $exit_code
}

$a = serialize $args $true
$pipe_name = "YashMaster\$pid"
$savetitle = $host.ui.rawui.windowtitle

try_spawn_server $pipe_name
$exitcode = client $pipe_name $a

$host.ui.rawui.windowtitle = $savetitle
exit $exitcode