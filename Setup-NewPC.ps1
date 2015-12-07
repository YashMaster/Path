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
#
#	#Remove WinMerge from ninite.exe

#http://jbeckwith.com/2012/11/28/5-steps-to-a-better-windows-command-line/





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
		Write-Host "Opening: " $Link
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

#Alternative method to [Environment]::SetEnvironmentVariable("Path", $env:Path + ";C:\Path", [EnvironmentVariableTarget]::Machine)
Function Have-RegKey
{	
	[CmdletBinding()]
	Param
	( 
		[Parameter(Mandatory=$true, ValueFromPipeline=$true)]
		[String]$Path,
		[Parameter(Mandatory=$true, ValueFromPipeline=$true)]
		[String]$Name,
		$Value
	)
	if(-not (Test-Path $Path))
		{New-Item -Path $Path}
	New-ItemProperty -Force -Path $Path -Name $Name -Value $Value 
}
############################################################################





#Step -2: Set working dir
Write-host "Setting the working directory: $Apps" -ForeGroundColor Green
cd $Apps



#Step -1.5: Copy over useful commands to @Path and add it to the %PATH%
Write-Host "Adding to the %PATH%: $Path" -ForegroundColor Green
Add-Path $Path



#Step -1: Make sure the script is running Elevated
if(!(Is-RunningElevated))
	{throw "Please relaunch with elevated privileges."}

	
#Install the fonts
$allFonts = "$Fonts\*.ttf"
Get-ChildItem $allFonts | ForEach-Object { Install-Font $_.FullName } 


#Enable some in PowerShell
Add-FontToPowerShell "000" "Monaco" $false
Add-FontToPowerShell "0000" "Source Code Pro" $true


#Step -0.75: Start installing a bunch-o-Ninite crap
Write-Host "Installing Ninite-o-rama... including: " -ForegroundColor Green
Write-Host -ForeGroundColor Green "--Chrome" 
Write-Host -ForeGroundColor Green "--CCCP" 
Write-Host -ForeGroundColor Green "--.NET 4.6" 
Write-Host -ForeGroundColor Green "--Adobe Air" 
Write-Host -ForeGroundColor Green "--PeaZip" 
Write-Host -ForeGroundColor Green "--WinDirStat" 
Write-Host -ForeGroundColor Green "--Python" 
Write-Host -ForeGroundColor Green "--Notepad++" 
Write-Host -ForeGroundColor Green "--WinSCP" 
Write-Host -ForeGroundColor Green "--PuTTY" 
Write-Host -ForeGroundColor Green "--WinMerge" 
.\NiniteInstaller.exe



#Step -0.5: Show a bunch of tabs that you'll have to manually deal with!
Write-Host "Opening a bunch of tabs you'll have to deal with manually..." -ForegroundColor Green
Open-IETabs `
	("https://portal.office.com/OLS/MySoftware.aspx", `
	"http://www.visualstudio.com/downloads/download-visual-studio-vs", `
	"http://osg/sites/jumpstart/_layouts/15/start.aspx#/SitePages/Home.aspx", `
	"https://desktop.github.com/")

	
	
#Step 0: Set the ExecutionPolicy to Unrestricted for the CurrentUser and both versions of PowerShell
Write-Host "Enabling future PowerShell scripts..." -ForegroundColor Green
Set-ExecutionPolicy -Scope CurrentUser Unrestricted -Force 
& $env:SystemRoot\System32\WindowsPowerShell\v1.0\PowerShell.exe -c "Set-ExecutionPolicy Unrestricted -Force"
& $env:SystemRoot\SysWOW64\WindowsPowerShell\v1.0\PowerShell.exe -c "Set-ExecutionPolicy Unrestricted -Force"
#Other, less pretty, solutions...
#Set-ExecutionPolicy -Scope LocalMachine Unrestricted -Force 
#Set-ExecutionPolicy -Scope CurrentUser Unrestricted -Force 
#Set-ItemProperty -Path 'HKLM:\Software\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell'-name "ExecutionPolicy" -Value "Unrestricted"
#Set-ItemProperty -Path 'HKLM:\Software\WOW6432Node\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell'-name "ExecutionPolicy" -Value "Unrestricted"



#Step 1: Enable Remote Desktop
Write-Host "Enabling Remote Desktop..." -ForegroundColor Green
New-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0 -Force
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"  
New-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name "UserAuthentication" -Value 0 -Force



#Step 2: Enable Delaylock
Write-Host "Enabling DelayLock..." -ForegroundColor Green
New-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name "DelayLockInterval" -Value 0x00000324 -PropertyType DWORD -Force
New-ItemProperty -Path 'HKLM:\Software\Policies\Microsoft\Windows\System' -Name "AllowDomainDelayLock" -Value 0x01 -PropertyType DWORD -Force


#Step 2.25: Disable Aero-Shake
Write-Host "Disabling Aero-Shake..." -ForegroundColor Green
Have-RegKey -Path 'HKCU:\Software\Policies\Microsoft\Windows\Explorer' -Name "NoWindowMinimizingShortcuts" -Value 00000001

#Step 2.5: Install Notification Center re-map
Write-Host "Installing NotificationCenterSanity..." -ForegroundColor Green
copy ".\WindowsTweaks\NotificationCenterSanity.exe" "$env:AppData\Microsoft\Windows\Start Menu\Programs\Startup\NotificationCenterSanity.exe"
& "$env:AppData\Microsoft\Windows\Start Menu\Programs\Startup\NotificationCenterSanity.exe"

#Step 3: Install Sound+Brightness re-map
Write-Host "Installing SoundBrightness re-map..." -ForegroundColor Green
copy ".\WindowsTweaks\AutoHotKey\SoundBrightness.exe" "$env:AppData\Microsoft\Windows\Start Menu\Programs\Startup\SoundBrightness.exe"
& "$env:AppData\Microsoft\Windows\Start Menu\Programs\Startup\SoundBrightness.exe"


#Use this to declare ps64
#For more details see: http://karlprosser.com/coder/2011/11/04/calling-powershell-64bit-from-32bit-and-visa-versa/
Write-Host "Installing Hyper-V and TelnetClient..." -ForegroundColor Green
Function Get-Ps64($emptyIfAlready64=$false)
{		
	if (-not [Environment]::Is64BitProcess)
		{ return "$env:windir\sysnative\WindowsPowerShell\v1.0\powershell.exe" }
	
	if ($emptyIfAlready64)
		{ return "" }
		
	return "$env:windir\System32\WindowsPowerShell\v1.0\powershell.exe"
}
$ps64 = Get-Ps64
& $ps64 Enable-WindowsOptionalFeature -Online -FeatureName TelnetClient -All
& $ps64 Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All



#Install-Package ConEmu -Force
#Install-Package git -params '"/GitAndUnixToolsOnPath /NoAutoCrlf"'.
#Get-PackageProvider -Name chocolatey -Force -ForceBootstrap
#Install-Package poshgit -Force
#Install-Package vim -Force
#Install-Package ConEmu -Force
#install-package -provider chocolatey -force cmder

#Install Scoop
iex (new-object net.webclient).downloadstring('https://get.scoop.sh')
#scoop install git
scoop install openssh
[environment]::setenvironmentvariable('GIT_SSH', (resolve-path (scoop which ssh)), 'USER')
scoop bucket add extras
scoop install conemu



#Woot, you're done! 
Write-Host "Done! Your computer is now awesome." -ForegroundColor Green
Write-Host "You should definitely restart now!" -ForegroundColor Green
Write-Host "You should definitely restart now!" -ForegroundColor Green






