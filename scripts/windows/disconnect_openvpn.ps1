# Requires OpenVPN GUI installed and available in PATH
# Run as: Right-click → Run with PowerShell
param(
  [string]$ProfileName
)

$ErrorActionPreference = "Stop"

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Write-Host "Elevating to Administrator..."
  $argsList = "-ExecutionPolicy Bypass -File `"$PSCommandPath`""
  if ($ProfileName) { $argsList += " -ProfileName `"$ProfileName`"" }
  Start-Process powershell -Verb runAs -ArgumentList $argsList
  exit
}

$ovpn = "openvpn-gui.exe"
# Prompt for profile if not provided
if (-not $ProfileName -or $ProfileName.Trim() -eq "") {
  $ProfileName = Read-Host "Enter your OpenVPN profile name (as shown in OpenVPN GUI)"
}
$cmd = "--command disconnect `"$ProfileName`""
Write-Host "Disconnecting profile: $ProfileName"
Start-Process -FilePath $ovpn -ArgumentList $cmd -WindowStyle Hidden
Write-Host "Disconnect command sent."
