#This is designed to help you setup a new PC
#This assumes you are Yashar and you prefer the best settings on your PC
#All else, don't use this script, or be sad

#TODO:
#	#Copy shortcuts to desktop
#	#Import notepad++ settings 
#	#Import conemu settings
#	#add file associations
#	#PowerShell: enable quickedit mode
#	#PowerShell: filter paste
#	#PowerShell: enable line wrapping
#	#Explorer: Show "details" view by default
#	#Explorer: Remove the "network" and "quickaccess" buttons 
#	#Explorer: Right-click: Get Path
#	#Explorer: Right-click: Duplicate
#	#Explorer: Right-click: Open PowerShell Here
#
#	Differentiate between desktop and laptop
#	* 	Configure power profiles accordingly
#	*	Set sleep to never if desktop



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
. "$workingdir\Microsoft.PowerShell_profile.ps1"

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

Write-Host -ForegroundColor Green "Copying over PowerShell profile..." 
$null = Declare-Copy "$workingdir\Microsoft.PowerShell_profile.ps1" $profile

Write-Host -ForegroundColor Green "Installing fonts..." 
$allFonts = "$Fonts\*.ttf"
Get-ChildItem $allFonts | ForEach-Object { Install-Font $_.FullName $_} 


Write-Host -ForegroundColor Green "Adding fonts to PowerShell..."
$null = Add-FontToPowerShell "000" "Monaco" $true
$null = Add-FontToPowerShell "0000" "Source Code Pro" $false


Write-Host -ForegroundColor Green "Installing Ninite-o-rama..." 
Write-Host -ForegroundColor Green  "--Chrome" 
Write-Host -ForegroundColor Green  "--7zip" 
Write-Host -ForegroundColor Green  "--WinDirStat" 
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
	"http://shop.gopro.com/softwareandapp/gopro-studio/GoPro-Studio.html",`
	"https://www.microsoft.com/accessories/en-us/downloads/mouse-keyboard-center",`
	"https://support.microsoft.com/en-us/help/12379/windows-10-mobile-device-recovery-tool-faq")

	
Write-Host -ForegroundColor Green "Enabling future PowerShell scripts..." 
Remove-ExecutionPolicy


Write-Host -ForegroundColor Green  "Enabling Remote Desktop..." 
$null = Declare-RegKey -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0x00
$null = Declare-RegKey -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name "UserAuthentication" -Value 0x00
$null = Enable-NetFirewallRule -DisplayGroup "Remote Desktop"  


Write-Host -ForegroundColor Green "Enabling DelayLock, PIN, and Secure-desktop-less UAC..." 
$null = Declare-RegKey -Path 'HKCU:\Control Panel\Desktop' -Name "DelayLockInterval" -Value 0x0324
$null = Declare-RegKey -Path 'HKLM:\Software\Policies\Microsoft\Windows\System' -Name "AllowDomainDelayLock" -Value 0x01
$null = Declare-RegKey -Path 'HKLM:\Software\Policies\Microsoft\Windows\System' -Name "AllowDomainPINLogon" -Value 0x01
$null = Declare-RegKey -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System' -Name "PromptOnSecureDesktop" -Value 0x00


Write-Host -ForegroundColor Green "Enabling ARSO..." 
$null = Declare-RegKey -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -Name "ARSOUserConsent" -Value 0x00000001
$null = Declare-RegKey -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -Name "TBALIgnorePolicyTestHook" -Value 0x00000001


Write-Host -ForegroundColor Green "Disabling Aero-Shake..." 
$null = Declare-RegKey -Path 'HKCU:\Software\Policies\Microsoft\Windows\Explorer' -Name "NoWindowMinimizingShortcuts" -Value 0x01


Write-Host -ForegroundColor Green "Disabling Lockscreen..." 
$null = Declare-RegKey -Path 'HKLM:\Software\Policies\Microsoft\Windows\Personalization' -Name "NoLockScreen" -Value 0x01


Write-Host -ForegroundColor Green "Configuring Windows Explorer and Shell..."
$null = Declare-RegKey -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'Hidden' -Value 0x01
$null = Declare-RegKey -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'HideFileExt' -Value 0x00
$null = Declare-RegKey -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'SnapAssist' -Value 0x00
# Change Explorer home screen to "This PC" (set to 0x02 to set it back to "Quick-Access")
$null = Declare-RegKey -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'LaunchTo' -Value 0x01
$null = Declare-RegKey -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer' -Name 'ShowRecent' -Value 0x00
$null = Declare-RegKey -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer' -Name 'ShowFrequent' -Value 0x00
$null = Declare-RegKey -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'DontPrettyPath' -Value 0x01


Write-Host -ForegroundColor Green "Disabling SmartScreen... Disable sending Store app URLs to SmartScreen..."
$null = Declare-RegKey -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppHost' -Name 'EnableWebContentEvaluation' -Value 0x00
$null = Declare-RegKey -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer' -Name 'SmartScreenEnabled' -Value 'Off'


#http://www.tenforums.com/tutorials/5918-windows-defender-turn-off-windows-10-a.html#option2
Write-Host -ForegroundColor Green "Disabling Windows Defender and Antimalware Service..."
$null = Declare-RegKey -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender' -Name 'DisableAntiSpyware' -Value 1
$null = Declare-RegKey -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run' -Name 'Windows Defender' -Value "-"
$null = Declare-RegKey -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run' -Name 'Windows Defender' -Value "-"
$null = Declare-RegKey -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run' -Name 'Windows Defender' -Value "-"


Write-Host -ForegroundColor Green "Enabling Developer Mode..."
#$null = Declare-RegKey -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' -Name 'AllowAllTrustedApps' -Value 0x01
$null = Declare-RegKey -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' -Name 'AllowDevelopmentWithoutDevLicense' -Value 0x01


Write-Host -ForegroundColor Green "Setting up Touchpad settings..."
$null = Declare-RegKey -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\PrecisionTouchPad' -Name 'RightClickZoneEnabled' -Value 0x00
$null = Declare-RegKey -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\PrecisionTouchPad' -Name 'ThreeFingerTapEnabled' -Value 0x02
$null = Declare-RegKey -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\PrecisionTouchPad' -Name 'ThreeFingerSlideEnabled' -Value 0x01
$null = Declare-RegKey -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\PrecisionTouchPad' -Name 'FourFingerTapEnabled' -Value 0x02
$null = Declare-RegKey -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\PrecisionTouchPad' -Name 'FourFingerSlideEnabled' -Value 0x02



#Write-Host -ForegroundColor Green "Getting rid of BSDR (Blocking Shutdown Resolver)..."
#Automatically end user services when the user logs off or shuts down the computer
#$null = Declare-RegKey -Path 'HKCU:\Control Panel\Desktop' -Name 'AutoEndTasks' -Value 0x01
#Delay before killing user processes after click on "End Task" button in Task Manager
#$null = Declare-RegKey -Path 'HKCU:\Control Panel\Desktop' -Name 'HungAppTimeout' -Value 1000
#Reduces system waiting time before killing user processes on logoff / shutdown
#$null = Declare-RegKey -Path 'HKCU:\Control Panel\Desktop' -Name 'WaitToKillAppTimeout' -Value 10000
#Reduces system waiting time before killing not responding services
#$null = Declare-RegKey -Path 'HKCU:\Control Panel\Desktop' -Name 'LowLevelHooksTimeout' -Value 3000


#Write-Host -ForegroundColor Green "Disabling Web Search from Start Menu..."
#$null = Declare-RegKey -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' -Name 'ConnectedSearchUseWeb' -Value 0x00


#Write-Host -ForegroundColor Green "Installing NotificationCenterSanity..." 
#Get-Process | ? {$_ -match "NotificationCenterSanity"} | kill
#copy ".\WindowsTweaks\NotificationCenterSanity.exe" "$env:AppData\Microsoft\Windows\Start Menu\Programs\Startup\NotificationCenterSanity.exe"
#& "$env:AppData\Microsoft\Windows\Start Menu\Programs\Startup\NotificationCenterSanity.exe"


#Write-Host -ForegroundColor Green "Installing SoundBrightness re-map..." 
#Get-Process | ? {$_ -match "SoundBrightness"} | kill
#copy ".\WindowsTweaks\AutoHotKey\SoundBrightness.exe" "$env:AppData\Microsoft\Windows\Start Menu\Programs\Startup\SoundBrightness.exe"
#& "$env:AppData\Microsoft\Windows\Start Menu\Programs\Startup\SoundBrightness.exe"


Write-Host -ForegroundColor Green "Installing Hyper-V and TelnetClient... (if you're asked to reboot, don't do it!)" 
$ps64 = Get-Ps64
$null = & $ps64 Enable-WindowsOptionalFeature -NoRestart -Online -FeatureName TelnetClient -All
$null = & $ps64 Enable-WindowsOptionalFeature -NoRestart -Online -FeatureName Microsoft-Hyper-V -All


Write-Host -ForegroundColor Green "Disabling the stupid WindowsError Reporting prompt..."
$null = Disable-WindowsErrorReporting
$null = Declare-RegKey -Path 'HKLM:\SOFTWARE\Microsoft\PCHealth\ErrorReporting' -Name 'DoReport' -Value 0x00
$null = Declare-RegKey -Path 'HKLM:\SOFTWARE\Microsoft\PCHealth\ErrorReporting' -Name 'ShowUI' -Value 0x00
$null = Declare-RegKey -Path 'HKCU:\SOFTWARE\Microsoft\Windows\Windows Error Reporting' -Name 'DontShowUI' -Value 0x01
$null = Declare-RegKey -Path 'HKCU:\SOFTWARE\Microsoft\Windows\Windows Error Reporting' -Name 'Disabled' -Value 0x01
$null = Declare-RegKey -Path 'HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting' -Name 'DontShowUI' -Value 0x01
$null = Declare-RegKey -Path 'HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting' -Name 'Disabled' -Value 0x01


#Existing Power Schemes (* Active) 
#----------------------------------- 
#Power Scheme GUID: 1ca6081e-7f76-46f8-b8e5-92a6bd9800cd  (Maximum Battery 
#Power Scheme GUID: 2ae0e187-676e-4db0-a121-3b7ddeb3c420  (Power Source Opt 
#Power Scheme GUID: 37aa8291-02f6-4f6c-a377-6047bba97761  (Timers off (Pres 
#Power Scheme GUID: 381b4222-f694-41f0-9685-ff5bb260df2e  (Balanced) 
#Power Scheme GUID: 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c  (High performance 
#Power Scheme GUID: a1841308-3541-4fab-bc81-f71556f20b4a  (Power saver) 
#Power Scheme GUID: a666c91e-9613-4d84-a48e-2e4b7a016431  (Maximum Performa 
#Power Scheme GUID: de7ef2ae-119c-458b-a5a3-997c2221e76e  (Energy Star) 
#Power Scheme GUID: e11a5899-9d8e-4ded-8740-628976fc3e63  (Video Playback) 
#PowerCfg -SetActive $x 
Write-Host -ForegroundColor Green "Disabling Adaptive Brightness..."
#http://supportishere.com/two-scripts-to-disabled-adaptive-display-brightness-ambient-light-sensor-in-windows-78/
Stop-Service SensrSvc
Set-Service SensrSvc -StartupType Disabled
$currentScheme = ((PowerCfg -GetActiveScheme).Split())[3]
PowerCfg -SetACValueIndex $currentScheme 7516b95f-f776-4464-8c53-06167f40cc99 fbd9aa66-9553-4097-ba44-ed6e9d65eab8 000
PowerCfg -SetDCValueIndex $currentScheme 7516b95f-f776-4464-8c53-06167f40cc99 fbd9aa66-9553-4097-ba44-ed6e9d65eab8 000

Write-Host -ForegroundColor Green "Setting other power settings..."
powercfg -change -monitor-timeout-ac 0
powercfg -change -standby-timeout-ac 0
powercfg -change -disk-timeout-ac 0
powercfg -change -hibernate-timeout-ac 0

powercfg -change -monitor-timeout-dc 0
powercfg -change -standby-timeout-dc 0
powercfg -change -disk-timeout-dc 0
powercfg -change -hibernate-timeout-dc 0

Write-Host -ForegroundColor Green "Removing annoying apps..."
Get-AppxPackage Microsoft.Office.Sway | Remove-AppxPackage
Get-AppxPackage TheNewYorkTimes.NYTCrossword | Remove-AppxPackage
Get-AppxPackage king.com.CandyCrushSodaSaga | Remove-AppxPackage
Get-AppxPackage Microsoft.WindowsPhone | Remove-AppxPackage
Get-AppxPackage Flipboard.Flipboard | Remove-AppxPackage
Get-AppxPackage Microsoft.MicrosoftOfficeHub | Remove-AppxPackage
Get-AppxPackage Microsoft.ConnectivityStore | Remove-AppxPackage
Get-AppxPackage Microsoft.BingFinance | Remove-AppxPackage
Get-AppxPackage Microsoft.BingNews | Remove-AppxPackage
Get-AppxPackage Microsoft.BingSports | Remove-AppxPackage
Get-AppxPackage Drawboard.DrawboardPDF | Remove-AppxPackage
Get-AppxPackage Microsoft.3DBuilder | Remove-AppxPackage
Get-AppxPackage Microsoft.Getstarted | Remove-AppxPackage
Get-AppxPackage XeroxCorp.PrintExperience | Remove-AppxPackage
Get-AppxPackage Microsoft.SkypeApp | Remove-AppxPackage
Get-AppxPackage Microsoft.FreshPaint | Remove-AppxPackage
Get-AppxPackage Microsoft.OneConnect | Remove-AppxPackage
Get-AppxPackage Microsoft.MicrosoftSolitaireCollection | Remove-AppxPackage
Get-AppxPackage GAMELOFTSA.Asphalt8Airborne | Remove-AppxPackage
Get-AppxPackage D52A8D61.FarmVille2CountryEscape | Remove-AppxPackage

Write-Host -ForegroundColor Green  "Updating help..."
Update-Help


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
Write-Host -ForegroundColor Green "You should definitely restart now!" 






