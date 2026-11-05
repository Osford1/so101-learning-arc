# install-usbipd.ps1 — install usbipd-win (needs Administrator)
#
#   powershell -ExecutionPolicy Bypass -File install-usbipd.ps1
#
# A UAC prompt will appear — click Yes. This is the ONE elevation the setup needs
# (a one-off `usbipd bind` per device also needs admin; `usbipd attach` never does).

$ErrorActionPreference = 'Continue'

Write-Host "Requesting elevation to install usbipd-win..." -ForegroundColor Cyan
$wingetArgs = @(
    'install', '--id', 'dorssel.usbipd-win',
    '--accept-source-agreements', '--accept-package-agreements', '--silent'
)
Start-Process -FilePath 'winget.exe' -ArgumentList $wingetArgs -Verb RunAs -Wait

$exe = "$env:ProgramFiles\usbipd-win\usbipd.exe"
if (Test-Path $exe) {
    Write-Host "usbipd-win installed." -ForegroundColor Green
    & $exe --version
    Write-Host ""
    Write-Host "Next: plug the follower's USB-C in, then run attach-arm.ps1" -ForegroundColor Yellow
} else {
    Write-Host "Install did not complete (UAC declined, or winget failed)." -ForegroundColor Red
    Write-Host "Manual fallback — in an ADMIN PowerShell:"
    Write-Host "  winget install --id dorssel.usbipd-win --accept-source-agreements --accept-package-agreements"
    Write-Host "  # or download the MSI: https://github.com/dorssel/usbipd-win/releases"
    exit 1
}
