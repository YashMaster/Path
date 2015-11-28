@echo off

REM No need to do nuthin' if we're already elevated.
:checkPrivileges
NET FILE 1>NUL 2>NUL
if '%errorlevel%' == '0' ( goto Elevated )

REM Replace double quotes with single quotes in the args
set command=%*
set command=%command:"='%

REM Wrap in double quotes and include the script invocation. 
REM Note: The whitespace at the end is intentional! It enables parsing commands that end in '\' e.g. "lift cd .\Desktop\"
set command="%~dp0\%~n0.ps1 -FromBat %command% "
set command=%command:\\=\%

REM Actually invoke PowerShell as an elevated user
%SystemRoot%\SysWOW64\WindowsPowerShell\v1.0\powershell.exe -NoProfile -ExecutionPolicy Unrestricted -Command %command%
exit /b

:Elevated
echo lift: already elevated