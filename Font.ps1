#Sources:
#	0: Install font to Windows:		http://stackoverflow.com/questions/16023238/installing-system-font-with-powershell
#	1: Install font to Windows: 	http://windowsitpro.com/scripting/trick-installing-fonts-vbscript-or-powershell-script
#	2: Add option in PowerShell: 	https://gist.github.com/wormeyman/9041798
#	3: Set in PowerShell: 			http://michaellwest.blogspot.com/2013/03/add-font-to-powershell-console.html
#	4: Check if enabled in Windows 	https://www.microsoft.com/en-us/Typography/TrueTypeInstall.aspx

#Sweet fonts:
#	Monaco: 						https://github.com/todylu/monaco.ttf
#	Source Code Pro: 				https://github.com/adobe-fonts/Source-Code-Pro
#	Menlo:							https://github.com/hbin/top-programming-fonts

#Installs font (singular) to Windows. Only works for TTF fonts (untested on others).
Function Install-Font($fontLocation, $fontName)
{
	Write-Output "Trying to add font: $fontLocation"
	
	if($fontLocation -eq $null -or -not (Test-Path $fontLocation))
	{
		Write-Error "Font location is invalid. Location is: $fontLocation"
		return
	}
	
	$FONTS = 0x14
	$objShell = New-Object -ComObject Shell.Application
	$objFolder = $objShell.Namespace($FONTS)
	
	$filename = [System.IO.Path]::GetFileName($fontLocation)
	$targetLocation = Join-Path $objFolder.Self.Path $filename
	if(Test-Path $targetLocation)
	{
		Write-Output "Font '$fontLocation' is already installed"
		return
	}
	$objFolder.CopyHere($fontLocation)
}

#Makes the font available to PowerShell. @keyName needs to be "0" or "00" or "000" etc... 
Function Add-FontToPowerShell($keyName, $fontName, $enable=$false)
{
	$null = New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Console\TrueTypeFont' -Name $keyName -Value $fontName -Force
	
	if($enable)
		{$null = New-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name "FaceName" -Value $fontName -Force}
}

Function Get-Font 
{
	<#
	.Synopsis
		Gets the fonts currently loaded on the system
	.Description
		Uses the type System.Windows.Media.Fonts static property SystemFontFamilies,
		to retrieve all of the fonts loaded by the system.  If the Fonts type is not found,
		the PresentationCore assembly will be automatically loaded
	.Parameter font
		A wildcard to search for font names
	.Example
		# Get All Fonts
		Get-Font
	.Example
		# Get All Lucida Fonts
		Get-Font *Lucida*
	#>
	
	Param($font = "*")
	
	if (-not ("Windows.Media.Fonts" -as [Type])) 
		{Add-Type -AssemblyName "PresentationCore"}       

	[Windows.Media.Fonts]::SystemFontFamilies | Where-Object { $_.Source -like "$font" } 
}

###################################################################
#Examples

#Install the fonts
#$fonts = "C:\Users\yabahman\OneDrive\Apps\Fonts\*.ttf"
#Get-ChildItem $fonts | ForEach-Object { Install-Font $_.FullName } 

#Enable some in PowerShell
#Add-FontToPowerShell "000" "Monaco" $false
#Add-FontToPowerShell "0000" "Source Code Pro" $true


