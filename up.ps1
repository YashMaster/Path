if(!$args) { "usage: sudo <cmd...>"; exit 1 }

function is_admin {
	return ([System.Security.Principal.WindowsIdentity]::GetCurrent().UserClaims | ? { $_.Value -eq 'S-1-5-32-544'})
}

function sudo_do($parent_pid, $dir, $cmd) {
	$src = 'using System.Runtime.InteropServices;
	public class Kernel {
		[DllImport("kernel32.dll", SetLastError = true)]
		public static extern bool AttachConsole(uint dwProcessId);
		[DllImport("kernel32.dll", SetLastError = true, ExactSpelling = true)]
		public static extern bool FreeConsole();
	}'

	$kernel = add-type $src -passthru

	& powershell -noprofile write-host 'i am a sibling to the third heat 1'
	write-host "freeing console in 5 seconds "
	write-host "$cmd`nexit `$lastexitcode"
	sleep 5
	$kernel::freeconsole()
	$kernel::attachconsole($parent_pid)

	#sleep 5
	write-output "console has been re-attached "
	write-output "command is still $cmd"
	
	& cmd.exe /c echo i-was-echo-d
	#sleep 5
	& powershell -noprofile write-host 'i am a sibling to the third heat'

	$p = new-object diagnostics.process; $start = $p.startinfo
	$start.filename = "powershell.exe"
	$start.arguments = "-noprofile $cmd`nexit `$lastexitcode"
	$start.useshellexecute = $false
	$start.workingdirectory = $dir
	$p.start()
	$p.waitforexit()

	$p.start()
	$p.waitforexit()

	& powershell -noprofile write-host 'i am a sibling to the third heat'
	& cmd.exe /c echo i-was-echo-d
	write-output "i was output'd"
	#write-host "i was hostwriten"
	echo hihi
	return $p.exitcode
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
	$null, $dir, $parent_pid, $cmd = $args
	$exit_code = sudo_do $parent_pid $dir (serialize $cmd)
	exit $exit_code
}

if(!(is_admin)) {
	[console]::error.writeline("sudo: you must be an administrator to run sudo")
	exit 1
}

$a = serialize $args $true
$wd = serialize (convert-path $pwd) # convert-path in case pwd is a PSDrive

$savetitle = $host.ui.rawui.windowtitle
$p = new-object diagnostics.process; $start = $p.startinfo
$start.filename = "powershell.exe"
$start.arguments = "-noprofile & '$pscommandpath' -do $wd $pid $a`nexit `$lastexitcode"
$start.verb = 'runas'
#$start.windowstyle = 'hidden'
try { $null = $p.start() }
catch { exit 1 } # user didn't provide consent
$p.waitforexit()
$host.ui.rawui.windowtitle = $savetitle

exit $p.exitcode