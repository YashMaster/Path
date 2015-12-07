#pass - because we deserve nice things too

#Important Note: 
#	-This is based off of @lukesampson's implementation in psutils. 
#   -Check out the original project here: https://github.com/lukesampson/psutils

#TODO
#   -Prevent anyone from using the pipe but the parent process
#       -This could always done by using some kind of encryption. However that feels overengineered and this entire implementation is already insecure, so i's not worth it.
#
#   -launch powershell twice IMMEDIATELY. this is basically what we do today, 
#   but we only have to launch the second powershell once instead of once per command.
#   -pipe security :( 
#	-HWND security :(

#Knwon Bugs
#	-Calling exit after calling pass will hang the window. I think this is because pass is waiting for its child processes to exit



$DebugOn = $false
$Source = @"
using System;
using System.IO;
using System.IO.Pipes;
using System.Threading;
using System.Threading.Tasks;

public static class Pipes
{
    public static int BuffSize = 8192;
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

    public static async Task<String> ReadCmdAsync(PipeStream pipe, int timeout = 3000)
    {
        String ret = "";
        using (var cancellationTokenSource = new CancellationTokenSource(timeout))
        //using(cancellationTokenSource.Token.Register(() => pipe.Disconnect()))
        using(cancellationTokenSource.Token.Register(() => pipe.Dispose()))
        {
            int receivedCount;
            try
            {
                var buffer = new byte[BuffSize];
                receivedCount = await pipe.ReadAsync(buffer, 0, BuffSize, cancellationTokenSource.Token);
                ret = System.Text.Encoding.Default.GetString(buffer);
                ret = ret.Substring(0, receivedCount);
            }
            catch (TimeoutException) {}
        }
        return ret;
    }
}
"@
if (-not ([System.Management.Automation.PSTypeName]'Pipes').Type) { Add-Type -TypeDefinition $Source -Language CSharp }

if (!$args) { "usage: sudo <cmd...>"; exit 1 }

function is_admin { return ([System.Security.Principal.WindowsIdentity]::GetCurrent().UserClaims | ? { $_.Value -eq 'S-1-5-32-544'}) }
if (!(is_admin)) { [console]::error.writeline("sudo: you must be an administrator to run sudo"); exit 1 }

function write_obj($pipe, $obj) { 
    $json = convertto-json $obj
    $sw = new-object system.io.streamwriter($pipe);
    $sw.writeline($json); 
    $sw.flush();
    #$sw.dispose(); 
}

function read_obj($pipe, $timeout=3000) { 
	if ($DebugOn) { write-host "before read" }
    $json = [Pipes]::ReadCmdAsync($pipe, $timeout).Result;
	if ($DebugOn) { write-host "after read: $json" }
    $obj = ConvertFrom-Json $json
    $obj
}

#Returns a pipe. Closes a pipe if an open one is passed
#Fun note: to list all pipes use: get-childitem "\\.\pipe\"
function get_pipe($pipe) {
    if($pipe -ne $null) { $pipe.Dispose(); } #Write-Host "pipe was not null: $pipe"

    $PipeSecurity = New-Object IO.Pipes.PipeSecurity
    $PipeSecurity.AddAccessRule((New-Object IO.Pipes.PipeAccessRule("Everyone", [IO.Pipes.PipeAccessRights]::FullControl, 0)))
    $pipe = New-Object IO.Pipes.NamedPipeServerStream($pipe_name, [IO.Pipes.PipeDirection]::InOut, 1, [IO.Pipes.PipeTransmissionMode]::Byte, 
        [IO.Pipes.PipeOptions]::Asynchronous, [Pipes]::BuffSize, [Pipes]::BuffSize, $PipeSecurity, 0, [IO.Pipes.PipeAccessRights]::ChangePermissions)

    $pipe
}

function sudo_do($parent_pid, $pipe_name, $dir) {
    $src = 'using System.Runtime.InteropServices;
    public class Kernel {
        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool AttachConsole(uint dwProcessId);
        [DllImport("kernel32.dll", SetLastError = true, ExactSpelling = true)]
        public static extern bool FreeConsole();
    }'
    if (-not $DebugOn){
        $kernel = add-type $src -passthru
        $kernel::freeconsole()
        $kernel::attachconsole($parent_pid)
    }

    $pipe = $null
    while ($true) {
        $pipe = get_pipe $pipe
        $ret = [Pipes]::ListenForConnection($pipe);
        if (-not $ret) { if ($DebugOn) { write-host "connection was no good..." }; continue }
		
        $obj = read_obj $pipe
		if ($obj.cmd.Length -le 0) { if ($DebugOn) { write-host "cmd length <= 0" }; continue}

        
        if ($obj.cmd -eq "exit") { break }

        $p = new-object diagnostics.process; $start = $p.startinfo
        $start.filename = "powershell.exe"
        $start.arguments = "-noprofile $($obj.cmd)`nexit `$lastexitcode"
        $start.useshellexecute = $false
        $start.workingdirectory = $obj.dir
        $p.start()
        $p.waitforexit()
        
		$props = @{ 'pid'   =   $pid;
					'dir'   =   (convert-path $pwd);
					'cmd'   =   $cmd; 
					'ret'   =   $p.exitcode; }
		$obj = New-Object -TypeName PSObject -Prop $props
		
        write_obj $pipe $obj
    }

    $pipe.Dispose()
} 

function try_spawn_server($pipe_name) {
    if (Test-Path "\\.\pipe\$pipe_name") { return } 
    if ($DebugOn) { write-host "Pipe doesn't exist, gotta create it" }

    $p = new-object diagnostics.process; $start = $p.startinfo
    $start.filename = "powershell.exe"
    $start.arguments = "-noprofile & '$pscommandpath' -do $pid $pipe_name`nexit `$lastexitcode"
    $start.verb = 'runas'
    $start.windowstyle = 'hidden'
    if ($DebugOn) { $start.windowstyle = 'normal' }

    try 	{ $null = $p.start() }
    catch 	{ exit 1 } #user didn't provide consent
}

function client($pipe_name, $cmd) {
    $props = @{ 'pid'   =   $pid;
                'dir'   =   (convert-path $pwd); #$pwd.Path;
                'cmd'   =   $cmd; 
				'ret'   =   0; }
    $obj = New-Object -TypeName PSObject -Prop $props
	
	$pipe = new-object System.IO.Pipes.NamedPipeClientStream($pipe_name);
	$pipe.Connect();
    write_obj $pipe $obj
    $response = read_obj $pipe
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
    $exit_code = sudo_do $parent_pid $parent_pipe_name $dir
    exit $exit_code
}

$a = serialize $args $true
$pipe_name = "YashMaster\$pid"
$savetitle = $host.ui.rawui.windowtitle

try_spawn_server $pipe_name
$exitcode = client $pipe_name $a

$host.ui.rawui.windowtitle = $savetitle
exit $exitcode