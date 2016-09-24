#Declares a RegKey Path must exist. I suppose this are called keys. but that whole nomenclature suxorz
Function Declare-RegPath
{
	[CmdletBinding()]
	Param
	( 
		[Parameter(Mandatory=$true, ValueFromPipeline=$true)]
		[String]$Path
	)
	if(Test-Path $Path)
		{ return }

	$parentPath = Split-Path $Path -Parent
	if(-not (Test-Path $parentPath))
		{ Declare-RegPath $parentPath }

	New-Item -Path $Path
}


#Declare that a regkey must exist #Examples
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
	
	#Make sure the path exists
	Declare-RegPath $Path
	
	if($PropertyType -ne "")
		{New-ItemProperty -Force -Path $Path -Name $Name -PropertyType $PropertyType -Value $Value}
	else 
		{New-ItemProperty -Force -Path $Path -Name $Name -Value $Value}
}


#Declare path must exist
Function Declare-Path
{	
	[CmdletBinding()]
	Param
	( 
		[Parameter(Mandatory=$true, ValueFromPipeline=$true)]
		[String]$Path
	)
	#$Path = Resolve-Path $Path

	if(-not (Test-Path $Path))
		{mkdir $Path}
}

#Move a file. This will work even if the file already exists or if the path does not. 
Function Declare-Move
{	
	[CmdletBinding()]
	Param
	( 
		[Parameter(Mandatory=$true, ValueFromPipeline=$true)]
		[String]$Source,
		[Parameter(Mandatory=$true, ValueFromPipeline=$true)]
		[String]$Destination
	)

	Declare-Path (Split-Path $Destination -Parent)
	Move-Item -Force $Source $Destination
}


#Move a file. This will work even if the file already exists or if the path does not. 
Function Declare-Copy
{	
	[CmdletBinding()]
	Param
	( 
		[Parameter(Mandatory=$true, ValueFromPipeline=$true)]
		[String]$Source,
		[Parameter(Mandatory=$true, ValueFromPipeline=$true)]
		[String]$Destination
	)

	Declare-Path (Split-Path $Destination -Parent)
	Copy-Item -Force $Source $Destination
}

Function Explore
{	
	[CmdletBinding()]
	Param
	( 
		[Parameter(ValueFromPipeline=$true)]
		[String]$Path="."
	)
	explorer $Path
}
Set-Alias Open Explore

$Desktop = [Environment]::GetFolderPath("Desktop")
Function Desktop 
{	
	cd $Desktop
}
Set-Alias Desk Desktop
Set-Alias Home Desktop

$OneDrive = (Get-ItemProperty -Path 'HKCU:\Software\Microsoft\OneDrive\' -Name UserFolder).UserFolder
Function OneDrive 
{	
	cd $OneDrive
}
Set-Alias SkyDrive Desktop

Function Quit
{
	exit
	#$host.SetShouldExit(0)
}
Set-Alias Leave Quit

