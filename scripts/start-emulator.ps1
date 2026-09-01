<#
.SYNOPSIS
    Starts the Android emulator with a window that fits on screen.

.DESCRIPTION
    The Pixel 10 Pro XL AVD is 1344x2992 px. At the emulator's automatic scale
    that window is taller than a 1080p laptop screen, and the emulator responds
    by parking itself at a negative Y coordinate - visible in the taskbar, but
    entirely above the desktop. This script pins window.scale/x/y in
    emulator-user.ini before every launch, because a cold boot resets that file
    back to automatic scaling.

.EXAMPLE
    .\start-emulator.ps1
    .\start-emulator.ps1 -ColdBoot          # ignore the saved snapshot
    .\start-emulator.ps1 -Scale 0.3         # bigger window
#>
[CmdletBinding()]
param(
    [string]$Avd = "Pixel_10_Pro_XL",
    [double]$Scale = 0.25,
    [int]$WindowX = 80,
    [int]$WindowY = 20,
    [switch]$ColdBoot,
    [int]$TimeoutSeconds = 300
)

$ErrorActionPreference = "Stop"

$sdk = if ($env:ANDROID_SDK_ROOT) { $env:ANDROID_SDK_ROOT }
       elseif ($env:ANDROID_HOME) { $env:ANDROID_HOME }
       else { "$env:LOCALAPPDATA\Android\sdk" }

$emulatorExe = Join-Path $sdk "emulator\emulator.exe"
$adb         = Join-Path $sdk "platform-tools\adb.exe"

foreach ($tool in @($emulatorExe, $adb)) {
    if (-not (Test-Path $tool)) { throw "Not found: $tool" }
}

if (Get-Process qemu-system-x86_64 -ErrorAction SilentlyContinue) {
    Write-Host "Emulator is already running." -ForegroundColor Yellow
    & $adb devices
    return
}

# Pin the window geometry. A cold boot rewrites this file with
# window.scale = -1 (automatic), which is what pushes the window off-screen.
$iniPath = Join-Path $env:USERPROFILE ".android\avd\$Avd.avd\emulator-user.ini"
if (Test-Path $iniPath) {
    $ini = Get-Content $iniPath
    $ini = $ini -replace '^window\.x\s*=.*',     "window.x = $WindowX"
    $ini = $ini -replace '^window\.y\s*=.*',     "window.y = $WindowY"
    $ini = $ini -replace '^window\.scale\s*=.*', ("window.scale = {0:F6}" -f $Scale)
    Set-Content -Path $iniPath -Value $ini -Encoding ascii
    Write-Host "Window pinned to ${WindowX},${WindowY} at scale $Scale" -ForegroundColor DarkGray
}

$args = @("-avd", $Avd)
if ($ColdBoot) {
    $args += "-no-snapshot-load"
    Write-Host "Cold boot: ignoring saved snapshot." -ForegroundColor Yellow
}

Write-Host "Starting $Avd ..."
Start-Process -FilePath $emulatorExe -ArgumentList $args -WindowStyle Normal

# While the emulator boots, adb prints "device offline" to stderr. Windows
# PowerShell turns native stderr into terminating NativeCommandErrors, so the
# polling loop must not run under ErrorActionPreference = Stop.
$ErrorActionPreference = "Continue"

$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
do {
    Start-Sleep -Seconds 5
    $booted = try { (& $adb -s emulator-5554 shell getprop sys.boot_completed 2>&1 | Out-String).Trim() }
              catch { "" }
    if ($booted -match '^1$') {
        Write-Host "Emulator ready." -ForegroundColor Green
        try { & $adb -s emulator-5554 shell input keyevent KEYCODE_WAKEUP 2>&1 | Out-Null } catch {}
        return
    }
} while ((Get-Date) -lt $deadline)

Write-Warning "Emulator did not report boot_completed within $TimeoutSeconds s."
Write-Warning "If it is stuck 'offline', run: .\stop-emulator.ps1 -Force; .\start-emulator.ps1 -ColdBoot"
