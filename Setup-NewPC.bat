@echo off
REM @cls

REM cd %~dp0
set ps=%SystemRoot%\SysWOW64\WindowsPowerShell\v1.0\powershell.exe
%ps% -NoProfile -ExecutionPolicy Unrestricted -Command "& {Start-Process %ps% -Verb RunAs -ArgumentList '-NoExit -NoProfile -ExecutionPolicy Bypass -File ""%~dp0\%~n0.ps1 %*""' }"

exit