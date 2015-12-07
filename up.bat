@echo off
REM All this script does it wrap arguments in a way that PowerShell can understand and execute PowerShell (not elevated yet!) with them


REM No need to do nuthin' if we're already elevated.
:checkPrivileges
NET FILE 1>NUL 2>NUL
if '%errorlevel%' == '0' ( goto Elevated )


REM Replace double quotes with single quotes in the args. Only if args were passed!		
REM Note 0: I don't know why but if you try to put the below conditional on a single line, it fails pretty hard... Keep it on separate lines.
set command=%*
if defined command (
	set command=%command:"='% 
)


REM Add the script invocation and wrap the entire thing in double quites. 
REM Note 0: The whitespace at the end is intentional! It enables parsing commands that end in '\' e.g. "lift cd .\Desktop\"
REM Note 1: The PowerShell script location is wrapped in single quotes in case there is a space. The & is necessary to invoke an expression wrapped in quotes
set command="& '%~dp0\%~n0.ps1' -FromBat %command% "


REM Actually invoke PowerShell as an elevated user
%SystemRoot%\SysWOW64\WindowsPowerShell\v1.0\powershell.exe -NoProfile -ExecutionPolicy Unrestricted -Command %command%
exit /b


:Elevated
echo lift: already elevated