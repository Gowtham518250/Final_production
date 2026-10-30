# Capture Android memory and service state over a timed physical-device soak.
# Run from PowerShell with Android platform-tools installed and USB debugging authorized.

[CmdletBinding()]
param(
    [string]$PackageName = "com.retailmind.app",
    [ValidateRange(1, 24)]
    [int]$DurationHours = 8,
    [ValidateRange(30, 3600)]
    [int]$IntervalSeconds = 300,
    [string]$OutputRoot = ".\artifacts\android-device-soak"
)

$ErrorActionPreference = "Stop"

$adbCommand = Get-Command adb -ErrorAction Stop
$adb = $adbCommand.Source
$deviceState = & $adb get-state 2>$null
if ($LASTEXITCODE -ne 0 -or ($deviceState -join "").Trim() -ne "device") {
    throw "No authorized ADB device found. Connect one phone and accept its USB-debugging prompt."
}

$runStamp = Get-Date -Format "yyyyMMdd-HHmmss"
$runDirectory = Join-Path $OutputRoot $runStamp
New-Item -ItemType Directory -Path $runDirectory -Force | Out-Null

$deviceDetails = [ordered]@{
    CapturedAt       = (Get-Date).ToString("o")
    Manufacturer     = ((& $adb shell getprop ro.product.manufacturer) -join "").Trim()
    Model            = ((& $adb shell getprop ro.product.model) -join "").Trim()
    AndroidVersion   = ((& $adb shell getprop ro.build.version.release) -join "").Trim()
    AndroidSdk       = ((& $adb shell getprop ro.build.version.sdk) -join "").Trim()
    LowRamDeviceFlag = ((& $adb shell getprop ro.config.low_ram) -join "").Trim()
    PackageName      = $PackageName
    DurationHours    = $DurationHours
    IntervalSeconds  = $IntervalSeconds
}
[PSCustomObject]$deviceDetails | ConvertTo-Json -Depth 4 |
    Set-Content -Encoding UTF8 (Join-Path $runDirectory "device-info.json")

(& $adb shell settings get secure enabled_notification_listeners 2>&1) |
    Set-Content -Encoding UTF8 (Join-Path $runDirectory "notification-listeners.txt")
(& $adb shell cmd appops get $PackageName POST_NOTIFICATION 2>&1) |
    Set-Content -Encoding UTF8 (Join-Path $runDirectory "notification-appop.txt")
(& $adb shell dumpsys deviceidle whitelist 2>&1) |
    Set-Content -Encoding UTF8 (Join-Path $runDirectory "deviceidle-whitelist.txt")

& $adb shell dumpsys gfxinfo $PackageName reset | Out-Null

$sampleCount = [Math]::Ceiling(($DurationHours * 3600) / $IntervalSeconds)
$records = [System.Collections.Generic.List[object]]::new()

for ($sample = 1; $sample -le $sampleCount; $sample++) {
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    Write-Host "Sample $sample/$sampleCount at $stamp"

    $memory = & $adb shell dumpsys meminfo $PackageName 2>&1
    $services = & $adb shell dumpsys activity services $PackageName 2>&1
    $processes = & $adb shell ps -A 2>&1 | Select-String -SimpleMatch $PackageName

    $memoryPath = Join-Path $runDirectory "meminfo-$stamp.txt"
    $servicePath = Join-Path $runDirectory "services-$stamp.txt"
    $processPath = Join-Path $runDirectory "processes-$stamp.txt"

    $memory | Set-Content -Encoding UTF8 $memoryPath
    $services | Set-Content -Encoding UTF8 $servicePath
    $processes | ForEach-Object { $_.Line } |
        Set-Content -Encoding UTF8 $processPath

    $pssLine = ($memory | Select-String "TOTAL PSS|TOTAL" |
        Select-Object -First 1).Line
    $rssLine = ($memory | Select-String "TOTAL RSS" |
        Select-Object -First 1).Line
    $serviceLine = ($services | Select-String "BackgroundService|isForeground|foregroundId|startRequested" |
        Select-Object -First 8 | ForEach-Object { $_.Line }) -join " | "

    $records.Add([PSCustomObject]@{
        Timestamp            = (Get-Date).ToString("o")
        Sample               = $sample
        PssSummary           = $pssLine
        RssSummary           = $rssLine
        MatchingProcessCount = @($processes).Count
        ServiceStateSummary  = $serviceLine
        MemoryDump           = $memoryPath
        ServiceDump          = $servicePath
        ProcessDump          = $processPath
    })

    if ($sample -lt $sampleCount) {
        Start-Sleep -Seconds $IntervalSeconds
    }
}

$records | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $runDirectory "memory-summary.csv")

(& $adb shell dumpsys gfxinfo $PackageName framestats 2>&1) |
    Set-Content -Encoding UTF8 (Join-Path $runDirectory "gfxinfo-framestats.txt")
(& $adb shell dumpsys activity services $PackageName 2>&1) |
    Set-Content -Encoding UTF8 (Join-Path $runDirectory "final-services.txt")

$crashLines = & $adb logcat -d -t 20000 2>&1 |
    Select-String "AndroidRuntime|FATAL EXCEPTION|Fatal signal|ANR in|am_crash|am_anr|BackgroundService"
$crashLines | ForEach-Object { $_.Line } |
    Set-Content -Encoding UTF8 (Join-Path $runDirectory "crash-anr-logcat.txt")

Write-Host "Soak capture completed: $runDirectory"
