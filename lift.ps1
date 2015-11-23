#lift - Opens an elevated console 
#Typing "lift" will cause a UAC prompt but it will create a new window 
#You will stay in the same directory but it will not retain cmdhistory or anything like that
#
#Optional params:
#	-ps -ps32 -ps64 and -cmd
#		Default is -ps64. If multiple are passed the default is used.
#
#	-NoExit 
#		Keeps the current console window open.
 
#Longterm goal? sudo-equivalent:
#-Typing "sudo yourCommandHere" will run that command from elevated priviledges 
#-it will cause 1 UAC prompt the first time you use it from that console 
#-each time you use it after that, you will no longer be required to get the UAC prompt
 

#TODO
##Only kill the parent if it's a Cmd
##Run the command anyway, even if it's already elevated. Make sure you don't kill the parent then!
 
Param(  
	[switch]$Cmd = $false,
	[switch]$Use32 = $false,
	[switch]$NoExit = $false,
	[switch]$VerboseMode = $false
)  

Function Get-ConsolePath($Cmd, $Use32)
{	
	if    ($Cmd -and $Use32)
		{$ret = "$env:SystemRoot\System32\cmd.exe"}
		
	elseif($Cmd -and !$Use32)
		{$ret = "$env:SystemRoot\SysWOW64\cmd.exe"}
		
	elseif(!$Cmd -and $Use32)
		{$ret = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\PowerShell.exe"}
		
	else
		{$ret = "$env:SystemRoot\SysWOW64\WindowsPowerShell\v1.0\powershell.exe"}
	
	$ret
}

Function Get-CommandToRun($passedArgs)
{  	
	[string]$toRun = ""
	foreach ($arg in $passedArgs)  
		{$toRun += " " + $arg} #Note the whitespace! Keep it there or you will be sad!
	
	$ret = ""
	$ret += "cd " + (Resolve-Path .\).Path + ";"

	if($toRun.Length -ge 1)
	{
		#I have no idea why, but "write-output" really messes things up here...
		#And "echo" causes it to return all the info on different lines... Write-Host it is!
		#Write-Host "torun: " $toRun
		$ret += "Write-Host ""$($toRun)"";"
		$ret += "$($toRun);"
	}
	
	
	$ret
}

Function Print-Args($passedArgs)
{
	Write-Output "Cmd:		$($Cmd)"
	Write-Output "Use32:		$($Use32)"
	Write-Output "NoExit:		$($NoExit)"
	Write-Output "VerboseMode:	$($VerboseMode)"
	
	$i = 0
	foreach ($arg in $passedArgs)  
	{
		Write-Output "arg[$i]:		$($arg)"
		$i++
	}	
	
	Write-Output "ConsolePath:	$($ConsolePath)"
	Write-Output "Command:	$($Command)"
}

Function IsRunningElevated()
{
	$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
	$principal = new-object Security.Principal.WindowsPrincipal $identity
	$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)  
}

#Set-PSDebug -Trace 1

$ConsolePath = Get-ConsolePath $Cmd $Use32
$Command = Get-CommandToRun $args

if($VerboseMode)
	{Print-Args $args}

#Make sure the script isn't already elevated
if(IsRunningElevated)
{
	Write-Output "lift: already elevated"
	break
}


#Actually launch this bitch
$ArgList = "'-NoProfile -NoExit -ExecutionPolicy Unrestricted -Command """ + $Command + """'"
$StartMe = "Start-Process $ConsolePath -Verb RunAs -ArgumentList $ArgList"
if($VerboseMode)
{	
	Write-Output "arglist:	$($ArgList)" 
	Write-Output "startme:	$($StartMe)"
}
Invoke-Expression $StartMe 

#If we don't need to cleanup the parent conhost, then we're done here!
if($NoExit)
	{break}
	
#Kill the old PS window...If we were run from cmd.exe, we have to explicitly kill it; calling "exit" just exits this ps1 script
$ParentPid = (gwmi win32_process -Filter "processid='$pid'").parentprocessid; 
$ParentProc = [System.Diagnostics.Process]::GetProcessById($ParentPid)
if($VerboseMode)
{	
	Write-Output "parent: $($ParentPid)"
	Write-Output "parentProc: $($ParentProc)"
}
Stop-Process $ParentPid


#TODO Only kill the parent if it's a cmd! 
