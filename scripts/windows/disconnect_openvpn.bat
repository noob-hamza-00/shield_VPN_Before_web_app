@echo off
setlocal
set PROFILE_NAME=%~1
if "%PROFILE_NAME%"=="" (
  powershell -ExecutionPolicy Bypass -Command "$n = Read-Host 'Enter your OpenVPN profile name (as shown in OpenVPN GUI)'; Write-Output $n" > "%temp%\ovpn_profile.txt"
  set /p PROFILE_NAME=<"%temp%\ovpn_profile.txt"
  del "%temp%\ovpn_profile.txt" >nul 2>&1
)
powershell -ExecutionPolicy Bypass -File "%~dp0disconnect_openvpn.ps1" -ProfileName "%PROFILE_NAME%"
