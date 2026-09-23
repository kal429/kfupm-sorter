@echo off
title Build KFUPM Sorter installer
cd /d "%~dp0"
set "ISCC="
if exist "%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe"       set "ISCC=%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe"
if exist "%ProgramFiles%\Inno Setup 6\ISCC.exe"            set "ISCC=%ProgramFiles%\Inno Setup 6\ISCC.exe"
if exist "%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe"   set "ISCC=%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe"
if "%ISCC%"=="" (
  echo Inno Setup 6 is not installed.
  echo.
  echo Install it once, then run this file again:
  echo    winget install JRSoftware.InnoSetup
  echo or download it from https://jrsoftware.org/isdl.php
  echo.
  pause
  exit /b 1
)
"%ISCC%" KFUPM-Sorter.iss
if errorlevel 1 ( echo. & echo BUILD FAILED & pause & exit /b 1 )
echo.
echo Done. Your installer is in:  installer\output\
explorer output
pause
