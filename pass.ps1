#Important Note: This is _heavily_ based off of @lukesampson's implementation in psutils. 
#   Check out the original project here: https://github.com/lukesampson/psutils
##
#lift - because we deserve nice things too
##
#
#TODO
#   -Prevent anyone from using the pipe but the parent process
#       -This could always done by using some kind of encryption. However that feels overengineerd and this entire implementation is already insecure, so i's not worth it.
#   -Bi-Directional communication
#   -See if there's a way to close this bitch without explicitly sending an exit command 
#   -See if there's a way to avoid the second powershell invocation
#       -AKA redirect currnet powershell better...
#       -Might be possible by starting with no console OR by starting 
#
#woah, i think i just realized why the second powershell is necessary. probably because there's some windows-specific code in shell-execute 
#which always creates a console for powershell. unfortunately we HAVE to use shellexecute otherwise, there's no way to elevate. 
#potential work around: 
#   -launch powershell twice IMMEDIATELY. this is basically what we do today, 
#   but we only have to launch the second powershell once instead of once per command.

#Interesting:
#   -no idea how to handle "cd" commands... pass back pwd of admin ps?

#TODO
#   -get return value! 
#   -security :( 
#    -figure out how to close this hidden console...
#   - DO THIS FIRST - try launching the second powershell immediately!


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

    public static async Task<String> ReadCmdAsync(NamedPipeServerStream pipe, int timeout = 3000)
    {
        String ret = "";
        using (var cancellationTokenSource = new CancellationTokenSource(timeout))
        using(cancellationTokenSource.Token.Register(() => pipe.Disconnect()))
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
    $sw.dispose(); 
}

function read_obj($pipe, $timeout=3000) { 
    $json = [Pipes]::ReadCmdAsync($pipe, $timeout).Result;
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
        if (-not $ret) { continue }

        $json = [Pipes]::ReadCmdAsync($pipe).Result;
        $obj = ConvertFrom-Json $json
        if ($obj.cmd -eq "exit") { break }

        $p = new-object diagnostics.process; $start = $p.startinfo
        $start.filename = "powershell.exe"
        $start.arguments = "-noprofile $($obj.cmd)`nexit `$lastexitcode"
        $start.useshellexecute = $false
        $start.workingdirectory = $obj.dir
        $p.start()
        $p.waitforexit()
        #$p.exitcode

    }

    $pipe.Dispose();
    return $p.exitcode
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

    try { $null = $p.start() }
    catch { exit 1 } #user didn't provide consent
}

function client($pipe_name, $cmd) {
    $pipe = new-object System.IO.Pipes.NamedPipeClientStream($pipe_name);
    $pipe.Connect(); 
    $sw = new-object System.IO.StreamWriter($pipe);

    $props = @{ 'pid'   =   $pid;
                'dir'   =   (convert-path $pwd); #$pwd.Path;
                'cmd'   =   $cmd; }
    $obj = New-Object -TypeName PSObject -Prop $props
    $json = ConvertTo-Json $obj

    $sw.WriteLine($json); 
    $sw.Flush();
    if ($DebugOn) { Write-Host "json: $json"}
    Sleep 2

    $sw.Dispose(); 
    $pipe.Dispose();
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
client $pipe_name $a

$host.ui.rawui.windowtitle = $savetitle
#exit $p.exitcode