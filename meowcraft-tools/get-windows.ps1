# Meowcraft one-line setup for Windows. Friends paste this into PowerShell:
#   irm https://raw.githubusercontent.com/pattyryke/meowcraft/main/meowcraft-tools/get-windows.ps1 | iex
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$dir = Join-Path $HOME '.meowcraft'
$tool = Join-Path $dir 'meowcraft-windows.ps1'
New-Item -ItemType Directory -Force -Path $dir | Out-Null
Write-Host '  =^.^=  Downloading Meowcraft...' -ForegroundColor Magenta
Invoke-WebRequest -UseBasicParsing -Uri 'https://raw.githubusercontent.com/pattyryke/meowcraft/main/meowcraft-tools/meowcraft-windows.ps1' -OutFile $tool
& (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe') -NoProfile -ExecutionPolicy Bypass -File $tool install
