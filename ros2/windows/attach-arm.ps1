# usbipd-win → attach the SO-101 follower's USB-serial adapter to WSL2
#
# Run in a NORMAL PowerShell (no admin needed) once the arm is plugged in
# and the device has been bound once (the script tells you if it isn't).
#
#   powershell -ExecutionPolicy Bypass -File attach-arm.ps1
#   powershell -ExecutionPolicy Bypass -File attach-arm.ps1 -BusId 4-1 -Distro Ubuntu-24.04
#
# Feetech adapter = CH340/CH343/CP210x class USB-serial bridge (VID 1A86 / 10C4).
# The first `usbipd bind` of a device needs Administrator ONCE (persistent after that).

param(
    [string]$BusId  = "",
    [string]$Distro = "Ubuntu-24.04"
)

$usbipd = (Get-Command usbipd -ErrorAction SilentlyContinue).Source
if (-not $usbipd) { $usbipd = "$env:ProgramFiles\usbipd-win\usbipd.exe" }
if (-not (Test-Path $usbipd)) {
    Write-Host "usbipd-win not found. Install it first (admin PowerShell):" -ForegroundColor Red
    Write-Host '  winget install --id dorssel.usbipd-win --accept-source-agreements --accept-package-agreements'
    exit 1
}

Write-Host "=== usbipd list ===" -ForegroundColor Cyan
& $usbipd list

# --- pick the device(s) -------------------------------------------------------
$targets = @()
if ($BusId -ne "") {
    $targets = @($BusId)
} else {
    # usbipd list rows: BUSID  VID:PID  DEVICE  STATE
    $rows = & $usbipd list | Select-String -Pattern '^\s*(\d+-\d+(?:-\d+)?)\s+([0-9a-fA-F]{4}:[0-9a-fA-F]{4})\s+(.*?)\s{2,}(.*)$'
    foreach ($r in $rows) {
        $id    = $r.Matches[0].Groups[1].Value
        $vidpid= $r.Matches[0].Groups[2].Value
        $name  = $r.Matches[0].Groups[3].Value
        $state = $r.Matches[0].Groups[4].Value.Trim()
        if ($vidpid -match '^(1a86|10c4|0403):' -or $name -match 'CH34|CP210|USB-SERIAL|USB Serial|Feetech') {
            $targets += $id
            Write-Host ("  candidate: {0}  {1}  {2}  [{3}]" -f $id, $vidpid, $name, $state) -ForegroundColor Yellow
        }
    }
}
if ($targets.Count -eq 0) {
    Write-Host "No USB-serial arm adapter found. Is the follower powered (12 V) and plugged in?" -ForegroundColor Red
    exit 1
}

foreach ($t in $targets) {
    # bind once (needs admin). Bind is persistent, so it only has to succeed once.
    try {
        & $usbipd bind --busid $t 2>&1 | Out-Null
    } catch { }
    Write-Host "attaching $t to $Distro ..." -ForegroundColor Green
    # usbipd 5.x: the distro is the VALUE of --wsl (there is no --distribution flag)
    & $usbipd attach --wsl $Distro --busid $t
}

Write-Host ""
Write-Host "Now inside WSL:  ls -l /dev/ttyACM*  &&  sudo chmod 666 /dev/ttyACM*" -ForegroundColor Cyan
Write-Host "If attach fails with 'device is not bound', run this once in an ADMIN PowerShell:" -ForegroundColor DarkGray
Write-Host "  usbipd bind --busid <BUSID>" -ForegroundColor DarkGray
