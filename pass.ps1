if(!$args) { "usage: sudo <cmd...>"; exit 1 }

function popup($msg){
    [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
    [System.Windows.Forms.MessageBox]::Show($msg) 
}

function is_admin {
    return ([System.Security.Principal.WindowsIdentity]::GetCurrent().UserClaims | ? { $_.Value -eq 'S-1-5-32-544'})
}

function sudo_do($parent_pid, $dir, $pipe_name, $cmd) {
    $src = 'using System.Runtime.InteropServices;
    public class Kernel {
        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool AttachConsole(uint dwProcessId);
        [DllImport("kernel32.dll", SetLastError = true, ExactSpelling = true)]
        public static extern bool FreeConsole();
    }'
    $kernel = add-type $src -passthru
    $kernel::freeconsole()
    $kernel::attachconsole($parent_pid)

<#
    $p = new-object diagnostics.process; $start = $p.startinfo
    $start.filename = "powershell.exe"
    $start.arguments = "-noprofile $cmd`nexit `$lastexitcode"
    $start.useshellexecute = $false
    $start.workingdirectory = $dir
    $p.start()
    $p.waitforexit()
#>

    $PipeSecurity = New-Object IO.Pipes.PipeSecurity
    $PipeSecurity.AddAccessRule((New-Object IO.Pipes.PipeAccessRule("Everyone", [IO.Pipes.PipeAccessRights]::FullControl, 0)))
    $pipe = New-Object IO.Pipes.NamedPipeServerStream(
        $pipe_name, 
        [IO.Pipes.PipeDirection]::InOut, 
        1, 
        [IO.Pipes.PipeTransmissionMode]::Byte, 
        [IO.Pipes.PipeOptions]::Asynchronous, 
        1024, 
        1024, 
        $PipeSecurity, 
        0, 
        [IO.Pipes.PipeAccessRights]::ChangePermissions)
    $ret = $pipe.WaitForConnection()
    $sr = new-object System.IO.StreamReader($pipe); 

    while ($true) 
    {
        $newcmd = $sr.ReadLine()
        #popup "got $newcmd"

        if ($newcmd -eq "exit")
            {break}

        $p = new-object diagnostics.process; $start = $p.startinfo
        $start.filename = "powershell.exe"
        $start.arguments = "-noprofile $newcmd`nexit `$lastexitcode"
        $start.useshellexecute = $false
        $start.workingdirectory = $dir
        $p.start()
        $p.waitforexit()
        #$p.exitcode
    }

    $sr.Dispose();
    $pipe.Dispose();

    return $p.exitcode
} 

function client($pipe_name, $cmd)
{
    $pipe = new-object System.IO.Pipes.NamedPipeClientStream($pipe_name);
    $pipe.Connect(); 
     
    Write-Host "Write some shit to the pipe."
    $sw = new-object System.IO.StreamWriter($pipe);

    $sw.WriteLine("ls"); 
    $sw.Flush();
    Write-Host "--ls"
    Sleep 2

    $sw.WriteLine($cmd); 
    $sw.Flush();
    Write-Host "--$cmd"
    Sleep 2

    $sw.WriteLine("exit"); 
    $sw.Flush();
    Write-Host "--exit"

    Write-Host "disposing..."
    $sw.Dispose(); 
    $pipe.Dispose();
}

function serialize($a, $escape) {
    if($a -is [string] -and $a -match '\s') { return "'$a'" }
    if($a -is [array]) {
        return $a | % { (serialize $_ $escape) -join ', ' }
    }
    if($escape) { return $a -replace '[>&]', '`$0' }
    return $a
}

if($args[0] -eq '-do') {
    $null, $dir, $parent_pid, $parent_pipe_name, $cmd = $args
    $exit_code = sudo_do $parent_pid $dir $parent_pipe_name (serialize $cmd)
    exit $exit_code
}

if(!(is_admin)) {
    [console]::error.writeline("sudo: you must be an administrator to run sudo")
    exit 1
}

$a = serialize $args $true
$wd = serialize (convert-path $pwd) # convert-path in case pwd is a PSDrive
$pipe_name = "\\.\pipe\YashMaster$pid"


$savetitle = $host.ui.rawui.windowtitle
$p = new-object diagnostics.process; $start = $p.startinfo
$start.filename = "powershell.exe"
$start.arguments = "-noprofile & '$pscommandpath' -do $wd $pid $pipe_name $a`nexit `$lastexitcode"
$start.verb = 'runas'
#$start.windowstyle = 'hidden'
try { $null = $p.start() }
catch { exit 1 } # user didn't provide consent

client $pipe_name $a



$host.ui.rawui.windowtitle = $savetitle

#exit $p.exitcode