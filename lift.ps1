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
	http://ambracode.com/index/show/182422
	
	TODO: implement "fall" which is the opposite
	TODO: launch source app with same commandline params but elevated
	TODO: PS: preserve command history (is this necessary?)
	TODO: PS: preserve previously onscreen text
	TODO: PS: preserve all objects and functions
	TODO: preserve the environment and environmentvariables
	
	TODO: Change powershell font	
#>

[cmdletbinding()] 
Param
(
	[switch]$Cmd = $false,
	[switch]$Use32 = $false,
	[switch]$NoExit = $false,
	[switch]$FromBat = $false,
	[switch]$FromLift = $false,
	$SourceHwnd,
	[Parameter(Position=0, ValueFromRemainingArguments=$true)]$args
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
		public const UInt32 WM_DESTROY = 0x0002;
		public const UInt32 WM_CLOSE = 0x0010;
		
		public const UInt32 SW_HIDE = 0;
		public const UInt32 SW_SHOWNOACTIVATE = 4;
		public const UInt32 SW_SHOWNA = 8;
		public const UInt32 SW_RESTORE = 9;
		
		[DllImport("user32.dll")]
		public static extern IntPtr SendMessage(IntPtr hWnd, UInt32 Msg, Int32 wParam, Int32 lParam);
	
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

Function Get-UserRequestedCommand($passedArgs)
{  	
	$ret = "& "
	foreach ($arg in $passedArgs)  
		{$ret += "'$arg' "} #Note the whitespace! Keep it there or you will be sad!
	#$ret.TrimEnd(" ") Note: Leave the last space there! It helps prevent weird parsing bugs when the last command ends in '\'
	$ret
}

Function Get-UserRequestedCommandReadable($passedArgs)
{  	
	$ret = ""
	foreach ($arg in $passedArgs)  
		{$ret += "$arg "}
	$ret
}

#This the set of commands that need to be run in the target elevated PowerShell _before_ the command the user passed. 
#This does things like position the window properly, set the proper working directory, etc...
Function Get-CommandToRun($passedArgs)
{
	$ret = ""

	$SourceHwnd = [Win32]::GetConsoleWindow()
	
	#Runs this script again with the FromLift param set to true. Also propagates the @NoExit value
	if($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent)
		{$ret += "lift -FromLift -SourceHwnd $SourceHwnd -NoExit -Verbose;"}
	else
		{$ret += "lift -FromLift -SourceHwnd $SourceHwnd -NoExit:`$$NoExit;"}
	
	#Set the current directory accordingly
	$ret += "cd '" + (Resolve-Path .\).Path + "';"
	
	#If there's a @userRequested command, include commands to write those to the console and execute them
	if($passedArgs.Length -ge 1)
	{
		#I have no idea why, but "write-output" really messes things up here...
		#And "echo" causes it to return all the info on different lines... Write-Host it is!
		$ret += "Write-Host """ + (Get-UserRequestedCommandReadable $passedArgs) + """;"	#Shows which command the user wanted to run
		$ret += """" + (Get-UserRequestedCommand $passedArgs) + """;" 						#Actually runs the userCommand
	}
	
	$ret
}

Function Print-Args($passedArgs)
{
	Write-Verbose "Cmd:		$($Cmd)"
	Write-Verbose "Use32:		$($Use32)"
	Write-Verbose "NoExit:		$($NoExit)"
	Write-Verbose "FromBat:	$($FromBat)"
	Write-Verbose "FromLift:	$($FromLift)"
	Write-Verbose "SourceHwnd:	$($SourceHwnd)"
	
	$i = 0
	Write-Verbose "PassedArgs:"
	foreach ($arg in $passedArgs)  
	{
		Write-Verbose "`t[$i]:`t$($arg)"
		$i++
	}	
	
	Write-Verbose "ConsolePath:	$($ConsolePath)"
	Write-Verbose "UserRequestedCommand:	$($UserRequestedCommand)"
	Write-Verbose "Command:	$($Command)"
	$commandLine = (Get-WmiObject Win32_Process | where ProcessID -eq $pid).CommandLine
	Write-Verbose "CurrentProc CmdLine: $commandLine" 
	
	#$ParentPid = (gwmi win32_process -Filter "processid='$pid'").parentprocessid; 
	#$ParentProc = [System.Diagnostics.Process]::GetProcessById($ParentPid)
	#Write-Verbose "parent: $($ParentPid)"
	#Write-Verbose "parentProc: $($ParentProc)"
}

Function IsRunningElevated()
{
	$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
	$principal = New-Object Security.Principal.WindowsPrincipal $identity
	$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)  
}





#====================================================================================================	
$ConsolePath = Get-ConsolePath $Cmd $Use32
$UserRequestedCommand = Get-UserRequestedCommand $args
$Command = Get-CommandToRun $args

Write-Verbose "Invocation: $($MyInvocation.Line)"
Print-Args $args

#If we were launched _from_ the lift script (i.e. just elevated) then initalize state
if($FromLift)
{
	$ret = [Win32]::SetForegroundWindow($SourceHwnd)
	
	$sourceRect = New-Object Rect
	$ret = [Win32]::GetWindowRect($SourceHwnd, [ref]$sourceRect)
	$targetHwnd = [Win32]::GetConsoleWindow()
	
	#MoveWindow can't be called while th window is hidden or minimized. 
	$ret = [Win32]::ShowWindow($targetHwnd, [Win32]::SW_RESTORE)
	$ret = [Win32]::MoveWindow($targetHwnd, [ref]$sourceRect)
	
	#The following two lines eliminate the "restore" animation
	$ret = [Win32]::ShowWindow($targetHwnd, [Win32]::SW_HIDE)
	$ret = [Win32]::ShowWindow($targetHwnd, [Win32]::SW_SHOWNOACTIVATE)
	
	#Kill the source window 
	if(-not $NoExit)
	{
		$ret = [Win32]::SetForegroundWindow($SourceHwnd)
		$ret = [Win32]::SendMessage($SourceHwnd, [Win32]::WM_CLOSE	, 0, 0)
	}

	return
}

#Make sure the script isn't already elevated
if(IsRunningElevated)
{
	Write-Output "lift: already elevated"
	if ($UserRequestedCommand -ne "")
		{Invoke-Expression $UserRequestedCommand}
		
	break
}

#Start application
try
{
	$process = New-Object System.Diagnostics.Process
	$process.StartInfo = (Get-Process -Id $pid).StartInfo
	$process.StartInfo.FileName = $ConsolePath
	$process.StartInfo.Arguments = "-NoExit -ExecutionPolicy Unrestricted -Command """ + $Command + """"
	$process.StartInfo.WindowStyle = 2 #Start minimized
	$process.StartInfo.Verb = "runas"
	$process.Start() | Out-Null
}
catch [System.Exception]
{
	Write-Output "lift: UAC prompt was not accepted."	
	return
}
Write-Output "lift: elevating..."
Sleep 1

#Exit the new powershell console we created... if we created one from the bat
if($FromBat)
	{$host.SetShouldExit(0)}




