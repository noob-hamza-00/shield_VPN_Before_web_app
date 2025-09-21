# Requires OpenVPN GUI installed and available in PATH
# Run as: Right-click → Run with PowerShell
param(
  [string]$ProfileName
)

$ErrorActionPreference = "Stop"

# Ensure running as admin (OpenVPN needs elevation to add routes)
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Write-Host "Elevating to Administrator..."
  $argsList = "-ExecutionPolicy Bypass -File `"$PSCommandPath`""
  if ($ProfileName) { $argsList += " -ProfileName `"$ProfileName`"" }
  Start-Process powershell -Verb runAs -ArgumentList $argsList
  exit
}

# Use OpenVPN GUI command interface
$ovpn = "openvpn-gui.exe"
# Prompt for profile if not provided
if (-not $ProfileName -or $ProfileName.Trim() -eq "") {
  $ProfileName = Read-Host "Enter your OpenVPN profile name (as shown in OpenVPN GUI)"
}
$cmd = "--command connect `"$ProfileName`""
Write-Host "Connecting profile: $ProfileName"
Start-Process -FilePath $ovpn -ArgumentList $cmd -WindowStyle Hidden

# Poll status by checking route to a common public IP (e.g., 1.1.1.1) through TAP adapter
Start-Sleep -Seconds 2
$max = 20
for ($i=0; $i -lt $max; $i++) {
  $tap = Get-NetAdapter | Where-Object { $_.InterfaceDescription -match 'TAP' -and $_.Status -eq 'Up' }
  if ($tap) {
    Write-Host "VPN interface up: $($tap.Name)"
    Write-Host "Connected."
    exit 0
  }
  Start-Sleep -Seconds 1
}
Write-Error "Timed out waiting for VPN connection. Ensure profile name is correct and OpenVPN GUI is running."
exit 1
