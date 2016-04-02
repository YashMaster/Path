#This is designed to help you setup a new PC
#This assumes you are Yashar and you prefer the best settings on your PC
#All else, don't use this script, or be sad
#
#TODO:
#	#Set sleep to never if desktop
#	#Copy shortcuts to desktop
#	#Add %OneDrive% env var 
#	#Add PS configurations
#	#Add PowerSHell Profile
#	#Import notepad++ settings 
#	#update help
#	#add "explore" as alias for "explorer ."
#	#Import conemu settings
#	#Configure good File Explorer "Quick-Access" links
#	#Right-click "Open powershell here"
#	#Always show Right-click "Get path" 
#	#add file associations
#	#Powershell: enable quickedit mode
#	#Powershell: filter paste
#	#Powershell: enable line wrapping
#	#Enable NGC PIN password provider
#
#   #Grant user permission for RDP acccess
#   #Three finger tap == notificationcenter 
#

#Get rid of these messages...
# "Outlook is not responding"
# "Windows can try to recover your information"
# "Close the program"

[CmdletBinding()]
Param 
(
	[string]$OneDrive 	= (Get-ItemProperty -Path 'HKCU:\Software\Microsoft\OneDrive\' -Name UserFolder).UserFolder,
	[string]$Apps	 	= "$OneDrive\Apps",
	[string]$Path 		= "$OneDrive\Path",
	[string]$Fonts 		= "$OneDrive\Apps\Fonts"
)

$workingdir = Split-Path $MyInvocation.MyCommand.Path -Parent
. "$workingdir\Font.ps1"  

#Checks if the current script is being run elevated 
Function Is-RunningElevated()
{
	$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
	$principal = New-Object Security.Principal.WindowsPrincipal $identity
	$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)  
}

#Opens IE Tabs...Has a dumb bug where it will create a blank one. Whatever. 
Function Open-IETabs
{
	[CmdletBinding()]
    Param 
	(
        [string[]]$Url
    )
	
	$Ie = New-Object -ComObject InternetExplorer.Application
	foreach ($Link in $Url) 
	{
		Write-Host -ForegroundColor Green "Opening: $Link"
		$Ie.Navigate2($Link, 0x10001)
	}
	$Ie.Visible = $true
}

#Alternative method to [Environment]::SetEnvironmentVariable("Path", $env:Path + ";C:\Path", [EnvironmentVariableTarget]::Machine)
Function Add-Path 
{	
	[CmdletBinding()]
	Param
	( 
		[Parameter(Mandatory=$true, ValueFromPipeline=$true, Position=0)]
		[String[]]$addedFolder
	)

	# Get the current search path from the environment keys in the registry.
	$oldPath=(Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name Path).Path

	# See if a new folder has been supplied.
	if (!$addedFolder)
		{return 'No Folder Supplied. $ENV:PATH Unchanged'}

	# See if the new folder exists on the file system.
	if (!(Test-Path $addedFolder))
		{return 'Folder Does not Exist, Cannot be added to $ENV:PATH'}

	# See if the new Folder is already in the path.
	if ($env:Path | Select-String -SimpleMatch $addedFolder)
		{return 'Folder already within $env:Path'}

	# Set the New Path
	$newPath = $oldPath + ";" + $addedFolder
	New-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Session Manager\Environment' -Name "Path" -Value $newPath -Force

	# Show our results back to the world
	return $newPath
}
	

Function Get-Path() { return $env:Path }

#Declare that a regkey must exist
Function Declare-RegKey
{	
	[CmdletBinding()]
	Param
	( 
		[Parameter(Mandatory=$true, ValueFromPipeline=$true)]
		[String]$Path,
		[Parameter(Mandatory=$true, ValueFromPipeline=$true)]
		[String]$Name,
		[Parameter(Mandatory=$true, ValueFromPipeline=$true)]
		$Value,
		[String]$PropertyType = ""
	)
	if(-not (Test-Path $Path))
		{New-Item -Path $Path}
	
	if($PropertyType -eq "")
		{New-ItemProperty -Force -Path $Path -Name $Name -PropertyType $PropertyType -Value $Value}
	else 
		{New-ItemProperty -Force -Path $Path -Name $Name -Value $Value}
}

#Examples
#Declare-RegKey "HKCU:\Control Panel\Desktopz" "DelayLockIntervalz234" String
#Declare-RegKey -Path 'HKCU:\Control Panel\Desktopz' -Name "DelayLockIntervalz23" -Value "string"
#Declare-RegKey -Path 'HKCU:\Control Panel\Desktopz' -Name "DelayLockIntervalz2" -Value 0x00000324
#Declare-RegKey -Path 'HKCU:\Control Panel\Desktopz' -Name "DelayLockIntervalz" -Value 0x00000324 -PropertyType String 
Function Declare-RegKey
{	
	[CmdletBinding()]
	Param
	( 
		[Parameter(Mandatory=$true, ValueFromPipeline=$true)]
		[String]$Path,
		[Parameter(Mandatory=$true, ValueFromPipeline=$true)]
		[String]$Name,
		[Parameter(Mandatory=$true, ValueFromPipeline=$true)]
		$Value,
		[String]$PropertyType = ""
	)
	if(-not (Test-Path $Path))
		{New-Item -Force -Path $Path }
	
	New-ItemProperty -Force -Path $Path -Name $Name -PropertyType $PropertyType -Value $Value
}

#Gets path to the 64 bit version of PowerShell
#For more details see: http://karlprosser.com/coder/2011/11/04/calling-powershell-64bit-from-32bit-and-visa-versa/
Function Get-Ps64($emptyIfAlready64=$false)
{		
	if (-not [Environment]::Is64BitProcess)
		{ return "$env:windir\sysnative\WindowsPowerShell\v1.0\powershell.exe" }
	
	if ($emptyIfAlready64)
		{ return "" }
		
	return "$env:windir\System32\WindowsPowerShell\v1.0\powershell.exe"
}

#Checks if a command exists
#http://blogs.technet.com/b/heyscriptingguy/archive/2013/02/19/use-a-powershell-function-to-see-if-a-command-exists.aspx
Function Test-CommandExists($command)
{
	$oldPreference = $ErrorActionPreference
	$ErrorActionPreference = 'stop'
	$ret = $false;
	try {if(Get-Command $command){$ret = $true}}
	catch {$ret = $false}
	finally {$ErrorActionPreference=$oldPreference}
	$ret
}

#Sets execution policy to 'Unrestricted'
Function Remove-ExecutionPolicy()
{
	$oldPreference = $ErrorActionPreference
	$ErrorActionPreference = 'SilentlyContinue'
	try 
	{
		& $env:SystemRoot\System32\WindowsPowerShell\v1.0\PowerShell.exe -c "Set-ExecutionPolicy Bypass -Force"
		& $env:SystemRoot\SysWOW64\WindowsPowerShell\v1.0\PowerShell.exe -c "Set-ExecutionPolicy Bypass -Force"
		Set-ExecutionPolicy -Scope CurrentUser Bypass -Force

		#Other, less pretty, solutions...
		#Set-ExecutionPolicy -Scope LocalMachine Unrestricted -Force 
		#Set-ExecutionPolicy -Scope CurrentUser Unrestricted -Force 
		#Set-ItemProperty -Path 'HKLM:\Software\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell'-name "ExecutionPolicy" -Value "Unrestricted"
		#Set-ItemProperty -Path 'HKLM:\Software\WOW6432Node\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell'-name "ExecutionPolicy" -Value "Unrestricted"
	}
	finally { $ErrorActionPreference=$oldPreference }
}
############################################################################

Write-Host -ForegroundColor Green "Making sure we're elevated..." 
if(!(Is-RunningElevated))
	{throw "Please relaunch with elevated privileges."}

	
Write-Host -ForegroundColor Green "Setting the working directory: $Apps" 
cd $Apps

Write-Host -ForegroundColor Green "Adding to %PATH%: $Path" 
$null = Add-Path $Path

	
Write-Host -ForegroundColor Green "Installing fonts..." 
$allFonts = "$Fonts\*.ttf"
Get-ChildItem $allFonts | ForEach-Object { Install-Font $_.FullName $_} 


Write-Host -ForegroundColor Green "Adding fonts to PowerShell..."
$null = Add-FontToPowerShell "000" "Monaco" $true
$null = Add-FontToPowerShell "0000" "Source Code Pro" $false


Write-Host -ForegroundColor Green "Installing Ninite-o-rama..." 
Write-Host -ForegroundColor Green  "--Chrome" 
#Write-Host -ForegroundColor Green  "--Adobe Air" 
#Write-Host -ForegroundColor Green  "--PeaZip" 
Write-Host -ForegroundColor Green  "--7zip" 
Write-Host -ForegroundColor Green  "--WinDirStat" 
#Write-Host -ForegroundColor Green  "--Python" 
Write-Host -ForegroundColor Green  "--Notepad++" 
Write-Host -ForegroundColor Green  "--WinSCP" 
Write-Host -ForegroundColor Green  "--PuTTY" 
.\NiniteInstaller.exe


Write-Host -ForegroundColor Green "Opening a bunch of tabs you'll have to deal with manually..." 
Open-IETabs `
	("https://portal.office.com/OLS/MySoftware.aspx", `
	"http://www.visualstudio.com/downloads/download-visual-studio-vs", `
	"http://osg/sites/jumpstart/_layouts/15/start.aspx#/SitePages/Home.aspx", `
	"https://desktop.github.com/",`
	"http://ejie.me/",`
	"http://shop.gopro.com/softwareandapp/gopro-studio/GoPro-Studio.html")

	
Write-Host -ForegroundColor Green "Enabling future PowerShell scripts..." 
Remove-ExecutionPolicy


Write-Host -ForegroundColor Green  "Enabling Remote Desktop..." 
$null = Declare-RegKey -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0x00
$null = Declare-RegKey -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name "UserAuthentication" -Value 0x00
$null = Enable-NetFirewallRule -DisplayGroup "Remote Desktop"  


Write-Host -ForegroundColor Green "Enabling DelayLock..." 
$null = Declare-RegKey -Path 'HKCU:\Control Panel\Desktop' -Name "DelayLockInterval" -Value 0x0324
$null = Declare-RegKey -Path 'HKLM:\Software\Policies\Microsoft\Windows\System' -Name "AllowDomainDelayLock" -Value 0x01

Write-Host -ForegroundColor Green "Enabling ARSO..." 
$null = Declare-RegKey -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -Name "ARSOUserConsent" -Value 0x00000001
$null = Declare-RegKey -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -Name "TBALIgnorePolicyTestHook" -Value 0x00000001

Write-Host -ForegroundColor Green "Disabling Aero-Shake..." 
$null = Declare-RegKey -Path 'HKCU:\Software\Policies\Microsoft\Windows\Explorer' -Name "NoWindowMinimizingShortcuts" -Value 0x01


Write-Host -ForegroundColor Green "Disabling Lockscreen..." 
$null = Declare-RegKey -Path 'HKLM:\Software\Policies\Microsoft\Windows\Personalization' -Name "NoLockScreen" -Value 0x01

Write-Host -ForegroundColor Green "Configuring Windows Explorer..."
$null = Declare-RegKey -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'Hidden' -Value 0x01
$null = Declare-RegKey -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'HideFileExt' -Value 0x00
$null = Declare-RegKey -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'SnapAssist' -Value 0x00



Write-Host -ForegroundColor Green "Enabling Developer Mode..."
#$null = Declare-RegKey -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' -Name 'AllowAllTrustedApps' -Value 0x01
$null = Declare-RegKey -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' -Name 'AllowDevelopmentWithoutDevLicense' -Value 0x01

#Write-Host -ForegroundColor Green "Getting rid of BSDR (Blocking Shutdown Resolver)..."
#Automatically end user services when the user logs off or shuts down the computer
#$null = Declare-RegKey -Path 'HKCU:\Control Panel\Desktop' -Name 'AutoEndTasks' -Value 0x01
#Delay before killing user processes after click on "End Task" button in Task Manager
#$null = Declare-RegKey -Path 'HKCU:\Control Panel\Desktop' -Name 'HungAppTimeout' -Value 1000
#Reduces system waiting time before killing user processes on logoff / shutdown
#$null = Declare-RegKey -Path 'HKCU:\Control Panel\Desktop' -Name 'WaitToKillAppTimeout' -Value 10000
#Reduces system waiting time before killing not responding services
#$null = Declare-RegKey -Path 'HKCU:\Control Panel\Desktop' -Name 'LowLevelHooksTimeout' -Value 3000


Write-Host -ForegroundColor Green "Installing NotificationCenterSanity..." 
Get-Process | ? {$_ -match "NotificationCenterSanity"} | kill
copy ".\WindowsTweaks\NotificationCenterSanity.exe" "$env:AppData\Microsoft\Windows\Start Menu\Programs\Startup\NotificationCenterSanity.exe"
& "$env:AppData\Microsoft\Windows\Start Menu\Programs\Startup\NotificationCenterSanity.exe"


Write-Host -ForegroundColor Green "Installing SoundBrightness re-map..." 
Get-Process | ? {$_ -match "SoundBrightness"} | kill
copy ".\WindowsTweaks\AutoHotKey\SoundBrightness.exe" "$env:AppData\Microsoft\Windows\Start Menu\Programs\Startup\SoundBrightness.exe"
& "$env:AppData\Microsoft\Windows\Start Menu\Programs\Startup\SoundBrightness.exe"


Write-Host -ForegroundColor Green "Installing Hyper-V and TelnetClient... (if you're asked to reboot, don't do it!)" 
$ps64 = Get-Ps64
$null = & $ps64 Enable-WindowsOptionalFeature -NoRestart -Online -FeatureName TelnetClient -All
$null = & $ps64 Enable-WindowsOptionalFeature -NoRestart -Online -FeatureName Microsoft-Hyper-V -All


Write-Host -ForegroundColor Green "Disabling the stupid WindowsError Reporting prompt..."
$null = Disable-WindowsErrorReporting

Write-Host -ForegroundColor Green "Disabling Adaptive Brightness..."
Stop-Service SensrSvc
Set-Service SensrSvc -StartupType Disabled
#http://supportishere.com/two-scripts-to-disabled-adaptive-display-brightness-ambient-light-sensor-in-windows-78/



Write-Host -ForegroundColor Green  "Installing scoop..."
if(-not (Test-CommandExists scoop))
	{iex (new-object net.webclient).downloadstring('https://get.scoop.sh')}
else 
	{scoop update}
scoop install git
scoop install openssh
[environment]::setenvironmentvariable('GIT_SSH', (resolve-path (scoop which ssh)), 'USER')
scoop bucket add extras
scoop install conemu


#Install-Package ConEmu -Force
#Install-Package git -params '"/GitAndUnixToolsOnPath /NoAutoCrlf"'.
#Get-PackageProvider -Name chocolatey -Force -ForceBootstrap
#Install-Package poshgit -Force
#Install-Package vim -Force
#Install-Package ConEmu -Force
#install-package -provider chocolatey -force cmder



#Install flux
#choco install f.lux

Write-Host -ForegroundColor Green "Done! Your computer is now awesome." 
Write-Host -ForegroundColor Green "You should definitely restart now!" 
Write-Host -ForegroundColor Green "You should definitely restart now!" 






