#This is designed to help you setup a new PC
#This assumes you are Yashar and you prefer the best settings on your PC
#All else, don't use this script, or be sad
#Set-PSDebug -Trace 1
#
#TODO:
##Set sleep to never if desktop. 
##Copy shortcuts to desktop


#Checks if the current script is being run elevated 
Function IsRunningElevated()
{
	$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
	$principal = New-Object Security.Principal.WindowsPrincipal $identity
	$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)  
}

#Opens IE Tabs...Has a dumb bug where it will create a blank one. Whatever. 
Function Open-IETabs
{
    param 
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
############################################################################



#Step -2: Set working dir
Write-host "Getting OneDrive directory..." -ForeGroundColor Green
$OneDrive = (Get-ItemProperty -Path 'HKCU:\Software\Microsoft\OneDrive\' -Name UserFolder).UserFolder
cd "$OneDrive\Apps"



#Step -1: Make sure the script is running Elevated
if(!(IsRunningElevated))
	{throw "Please relaunch with elevated privileges."}



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



#Step 2.5: Install Notification Center re-map
Write-Host "Installing NotificationCenterSanity..." -ForegroundColor Green
copy ".\WindowsTweaks\NotificationCenterSanity.exe" "$env:AppData\Microsoft\Windows\Start Menu\Programs\Startup\NotificationCenterSanity.exe"
& "$env:AppData\Microsoft\Windows\Start Menu\Programs\Startup\NotificationCenterSanity.exe"



#Step 3: Install Sound+Brightness re-map
Write-Host "Installing SoundBrightness re-map..." -ForegroundColor Green
copy ".\WindowsTweaks\AutoHotKey\SoundBrightness.exe" "$env:AppData\Microsoft\Windows\Start Menu\Programs\Startup\SoundBrightness.exe"
& "$env:AppData\Microsoft\Windows\Start Menu\Programs\Startup\SoundBrightness.exe"


#Step 4: Copy over useful commands to C:\Path and add it to the %PATH%
Write-Host "Setting the environment variables..." -ForegroundColor Green
#copy .\Path C:\ -Recurse -Force
#Note these won't be usable until PowerShell is relaunched
#[Environment]::SetEnvironmentVariable("Path", $env:Path + ";C:\Path", [EnvironmentVariableTarget]::Machine)
$p1 = Get-Path
Add-Path "$OneDrive\Path"
$p2 = Get-Path
if ($p1 -eq $p2)
	{"they're equal!"}
else
	{"they aint equal!"}

Write-Host "Done! Your computer is now awesome." -ForegroundColor Green






