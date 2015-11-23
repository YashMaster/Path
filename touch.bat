@echo off
REM http://superuser.com/questions/10426/windows-equivalent-of-the-linux-command-touch
REM copy /b %1+,, %1

if not exist "%~1" type nul >>"%~1"& goto :eof
set _ATTRIBUTES=%~a1
if "%~a1"=="%_ATTRIBUTES:r=%" (copy "%~1"+,,) else attrib -r "%~1" & copy "%~1"+,, & attrib +r "%~1"