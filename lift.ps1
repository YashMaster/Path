<#
.SYNOPSIS
   Opens an elevated console.

.DESCRIPTION
	Typing "lift" will cause a UAC prompt but it will create a new window.
	You will stay in the same directory but it will not retain cmdhistory or anything like that.

.PARAMETER Cmd
    Specifies using cmd.exe instead of powershell.

.PARAMETER Use32
    Specifies using 32bit equivalents of the shell.

.PARAMETER NoExit
    Keeps the current console window open.

.PARAMETER FromBat
    For internal use only. Specifies that this script was launched from the .bat file equivalent. You shouldn't set this.

.PARAMETER FromLift
    For internal use only. Specifies that this script was launched from the newly elevated console. You shouldn't set this.

.NOTES
	TODO: Run the command anyway, even if it's already elevated. Make sure you don't kill the parent then!
	TODO: Handle when users _DO NOT_ accept the UAC prompt. 
	TODO: implement "fall" which is the opposite
	TODO: if already elevated, "lift X.exe" should still execute X.exe
	TODO: make sure it closes the source prompt if launched from cmd.exe
	TODO: remove the maximize animation 
	TODO: launch source app with same commandline params but elevated
	TODO: PS: preserve command history (is this necessary?)
	TODO: PS: preserve previously onscreen text
	TODO: PS: preserve all objects and functions
	TODO: preserve the environment and environmentvariables
	
	http://ambracode.com/index/show/182422
#>

 
Param
(
	[switch]$Cmd = $false,
	[switch]$Use32 = $false,
	[switch]$NoExit = $false,
	[switch]$FromBat = $false,
	[switch]$FromLift = $false,
	$SourceHwnd
)  

#All the Win32 functions you could ever desire
Add-Type @"
	using System;
	using System.Runtime.InteropServices;
	 
	public struct RECT
	{
		public int Left;
		public int Top;
		public int Right;
		public int Bottom;
	}
	 
	public class Win32 
	{
		[DllImport("user32.dll")]
		[return: MarshalAs(UnmanagedType.Bool)]
		public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
		
		[DllImport("user32.dll")]
		[return: MarshalAs(UnmanagedType.Bool)]
		public static extern bool SetForegroundWindow(IntPtr hWnd);

		[DllImport("user32.dll")]
		public static extern IntPtr GetForegroundWindow();

		[DllImport("Kernel32.dll")]
		public static extern IntPtr GetConsoleWindow();
		
		[DllImport("User32.dll")]
		public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
		
		[DllImport("user32.dll", SetLastError = true)]
		public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint);
		
		public static bool MoveWindow(IntPtr hwnd, ref RECT rc)
		{
			return MoveWindow(hwnd, rc.Left, rc.Top, rc.Right - rc.Left, rc.Bottom - rc.Top, true);
		}
	}
"@

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
	Write-Output "FromBat:	$($FromBat)"
	Write-Output "FromLift:	$($FromLift)"
	Write-Output "SourceHwnd:	$($SourceHwnd)"
	
	$i = 0
	Write-Output "PassedArgs:"
	foreach ($arg in $passedArgs)  
	{
		Write-Output "`t[$i]:		$($arg)"
		$i++
	}	
	
	Write-Output "ConsolePath:	$($ConsolePath)"
	Write-Output "Command:	$($Command)"
	$commandLine = (Get-WmiObject Win32_Process | where ProcessID -eq $pid).CommandLine
	Write-Output "CurrentProc CmdLine: $commandLine" 
	
}

Function IsRunningElevated()
{
	$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
	$principal = new-object Security.Principal.WindowsPrincipal $identity
	$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)  
}



#====================================================================================================
$ConsolePath = Get-ConsolePath $Cmd $Use32
$Command = Get-CommandToRun $args

Print-Args $args

#If we were launched _from_ the lift script (i.e. just elevated) then initalize state
if($FromLift)
{
	$targetHwnd = [Win32]::GetConsoleWindow()
	$sourceRect = New-Object Rect
	$ret = [Win32]::GetWindowRect($SourceHwnd, [ref]$sourceRect)
	$ret = [Win32]::MoveWindow($targetHwnd, [ref]$sourceRect)
	$ret = [Win32]::ShowWindow($targetHwnd, 9) #SW_RESTORE
	$ret = [Win32]::MoveWindow($targetHwnd, [ref]$sourceRect)
	return
}

#Make sure the script isn't already elevated
if(IsRunningElevated)
{
	Write-Output "lift: already elevated"
	break
}



##Start application
$SourceHwnd = [Win32]::GetConsoleWindow()
$process = New-Object System.Diagnostics.Process
$process.StartInfo = (Get-Process -Id $pid).StartInfo
#$process.StartInfo.UseShellExecute = 0
#$process.StartInfo.Environment = (Get-Process -Id $pid).StartInfo.Environment
#$process.StartInfo.EnvironmentVariables.Clear()
#foreach($var in (Get-Process -Id $pid).StartInfo.EnvironmentVariables)
#	{$process.StartInfo.EnvironmentVariables.Add($var.Name, $var.Value)}

$process.StartInfo.FileName = $ConsolePath
$process.StartInfo.Arguments = "-NoProfile -NoExit -ExecutionPolicy Unrestricted -Command """ + "lift -FromLift -SourceHwnd $SourceHwnd; " + $Command + """"
$process.StartInfo.WorkingDirectory = (Resolve-Path .\).Path #This doesn't actually set powershell's starting location. this is the _process'_ working dir
$process.StartInfo.WindowStyle = 2 #Start minimized
$process.StartInfo.Verb = "runas"
$process.Start() | Out-Null

$process.StartInfo

#If we don't need to cleanup the parent conhost, then we're done here!
if($NoExit)
	{break}

	
#Kill the old PS window...If we were run from cmd.exe, we have to explicitly kill it; calling "exit" just exits this ps1 script
$ParentPid = (gwmi win32_process -Filter "processid='$pid'").parentprocessid; 
$ParentProc = [System.Diagnostics.Process]::GetProcessById($ParentPid)
Write-Verbose "parent: $($ParentPid)"
Write-Verbose "parentProc: $($ParentProc)"

#Wait until the foreground window changes...
$ret = [Win32]::SetForegroundWindow($SourceHwnd)
Sleep 2
for($i=0; $i -lt 100; $i++)
{
	$fgw = [Win32]::GetForegroundWindow()
	#$fgw
	#$process.MainWindowHandle
	if([Win32]::GetForegroundWindow() -eq $process.MainWindowHandle)
	{
		#Stop-Process $ParentPid
		$host.SetShouldExit(0)
		exit
	}
	Start-Sleep -m 100
}
Write-Host "lift: the elevated shell is taking unusually long to launch..."
