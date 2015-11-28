REM @echo off
REM @cls
cd %~dp0
REM %SystemRoot%\SysWOW64\WindowsPowerShell\v1.0\powershell.exe -NoProfile -ExecutionPolicy Unrestricted -NoExit -Command "%~dp0\%~n0.ps1 %*"

REM if you wanted to autoelevate...
%SystemRoot%\SysWOW64\WindowsPowerShell\v1.0\powershell.exe -NoProfile -ExecutionPolicy Unrestricted -Command "& {Start-Process PowerShell -ArgumentList '-Verb RunAs -NoExit -NoProfile -ExecutionPolicy Bypass -File ""%~dp0\%~n0.ps1 %*""' }"

pause 
exit