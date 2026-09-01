<#
.SYNOPSIS
    Shuts the Android emulator down cleanly.

.DESCRIPTION
    Uses `adb emu kill`, which lets the emulator save its snapshot before
    exiting. Killing the qemu process instead leaves that snapshot half-written,
    and the next launch then hangs in the "offline" state and has to be
    recovered with a cold boot - so -Force is a last resort, not the default.

.EXAMPLE
    .\stop-emulator.ps1
    .\stop-emulator.ps1 -Force      # only if the clean shutdown will not finish
#>
[CmdletBinding()]
param(
    [switch]$Force,
    [int]$TimeoutSeconds = 60
)

$ErrorActionPreference = "Stop"

$sdk = if ($env:ANDROID_SDK_ROOT) { $env:ANDROID_SDK_ROOT }
       elseif ($env:ANDROID_HOME) { $env:ANDROID_HOME }
       else { "$env:LOCALAPPDATA\Android\sdk" }

$adb = Join-Path $sdk "platform-tools\adb.exe"
if (-not (Test-Path $adb)) { throw "Not found: $adb" }

$process = Get-Process qemu-system-x86_64 -ErrorAction SilentlyContinue
if (-not $process) {
    Write-Host "Emulator is not running." -ForegroundColor Yellow
    return
}

# adb writes to stderr in normal situations; Windows PowerShell would turn that
# into a terminating error under ErrorActionPreference = Stop.
$ErrorActionPreference = "Continue"

Write-Host "Requesting clean shutdown ..."
try { & $adb -s emulator-5554 emu kill 2>&1 | Out-Null } catch {}

$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
do {
    Start-Sleep -Seconds 2
    if (-not (Get-Process qemu-system-x86_64 -ErrorAction SilentlyContinue)) {
        Write-Host "Emulator stopped." -ForegroundColor Green
        return
    }
} while ((Get-Date) -lt $deadline)

if (-not $Force) {
    Write-Warning "Still running after $TimeoutSeconds s."
    Write-Warning "Re-run with -Force to kill it, then start with -ColdBoot next time."
    return
}

Write-Warning "Force killing - the snapshot may be left corrupt."
Get-Process qemu-system-x86_64 -ErrorAction SilentlyContinue | Stop-Process -Force
Get-Process emulator -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 3
try { & $adb kill-server 2>&1 | Out-Null } catch {}
try { & $adb start-server 2>&1 | Out-Null } catch {}
Write-Host "Killed. Next start should use: .\start-emulator.ps1 -ColdBoot" -ForegroundColor Yellow
