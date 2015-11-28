@echo off

REM No need to do nuthin' if we're already elevated.
:checkPrivileges
NET FILE 1>NUL 2>NUL
if '%errorlevel%' == '0' ( goto Elevated )

echo Elevating...
REM %SystemRoot%\SysWOW64\WindowsPowerShell\v1.0\powershell.exe -NoProfile -ExecutionPolicy Unrestricted -Command "cd %~dp0; .\%~n0.ps1 %*"
REM %SystemRoot%\SysWOW64\WindowsPowerShell\v1.0\powershell.exe -NoProfile -ExecutionPolicy Unrestricted -Command "%~dp0\%~n0.ps1 '%*'"
echo %~n0.ps1 -FromBat %*
%SystemRoot%\SysWOW64\WindowsPowerShell\v1.0\powershell.exe -NoProfile -ExecutionPolicy Unrestricted -Command "%~dp0\%~n0.ps1 -FromBat %*"

exit /b

:Elevated
echo lift: already elevated
