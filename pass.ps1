#add-Type -assembly "System.Core" 
#[reflection.Assembly]::LoadWithPartialName("system.core")

#Entry for -wait
if($args[0] -eq '-wait') {
    $null, $parent_pid, $name = $args
    $name

    $PipeSecurity = New-Object IO.Pipes.PipeSecurity
    $pipe = New-Object IO.Pipes.NamedPipeServerStream($name, [IO.Pipes.PipeDirection]::InOut, 1, [IO.Pipes.PipeTransmissionMode]::Byte, [IO.Pipes.PipeOptions]::Asynchronous, 1024, 1024, $PipeSecurity, 0, [IO.Pipes.PipeAccessRights]::ChangePermissions)
    #$PipeSecurity = $PipeServer.GetAccessControl()
    $PipeSecurity.AddAccessRule((New-Object IO.Pipes.PipeAccessRule("Everyone", [IO.Pipes.PipeAccessRights]::FullControl, 0)))
    $pipe.SetAccessControl($PipeSecurity)
    #$ConnectResult = $PipeServer.BeginWaitForConnection($null, $null)
    
    Write-Host "Waiting for connections..."
    $ret = $pipe.WaitForConnection()
    Write-Host "Created server side of $name"

    $sr = new-object System.IO.StreamReader($pipe); 
    Write-Host "created streamreader..."

    while ($true) 
    {
        $cmd = $sr.ReadLine()
        Write-Host "got command: $cmd"

        if ($cmd -eq "exit")
            {break}
    }

    Write-Host "we're about to exit this in 5 seconds "
    sleep 5

    $sr.Dispose();
    $pipe.Dispose();

    exit $exit_code
}


#Check if a process to pass commands to already exists


#If it doesn't, create it
$pipeName = "\\.\pipe\YashMaster"

$p = new-object diagnostics.process; $start = $p.startinfo
$start.filename = "powershell.exe"
$start.arguments = "-noprofile & '$pscommandpath' -wait $pid $pipeName"
$start.verb = 'runas'
#$start.windowstyle = 'hidden'
try { $null = $p.start() }
catch { write-error "you gotsta accept UAC bro"; exit 1 } # user didn't provide consent

Write-Host "Created process, now we wait a bit..."
Sleep 3

Write-Host "Connecting to the pipe..."
$pipe = new-object System.IO.Pipes.NamedPipeClientStream($pipeName);
$pipe.Connect(); 
 
Write-Host "Write some shit to the pipe."
$sw = new-object System.IO.StreamWriter($pipe);

$sw.WriteLine("Go"); 
$sw.Flush();
Write-Host "--Go"
Sleep 5

$sw.WriteLine("start abc 123"); 
$sw.Flush(); 
Write-Host "--start abc 123"
Sleep 5

$sw.WriteLine("bla bla"); 
$sw.Flush();
Write-Host "--bla bla"
Sleep 5

$sw.WriteLine("exit"); 
$sw.Flush();
Write-Host "--exit"
Sleep 5

Write-Host "disposing..."
$sw.Dispose(); 
$pipe.Dispose();


