param(
    [string]$Serial = "127.0.0.1:16384",
    [string]$AdbPath = "D:\Program Files\Netease\MuMu\nx_device\12.0\shell\adb.exe"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $AdbPath)) {
    throw "MuMu adb not found: $AdbPath"
}

function Invoke-Adb {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Args)
    & $AdbPath @Args
    if ($LASTEXITCODE -ne 0) {
        throw "adb command failed: $($Args -join ' ')"
    }
}

function Assert-DeviceConnected {
    $devices = & $AdbPath devices
    $serialPattern = [regex]::Escape($Serial)
    $isConnected = @($devices | Where-Object { $_ -match "^$serialPattern\s+device$" }).Count -gt 0
    if (-not $isConnected) {
        throw "MuMu device $Serial is not connected. Open MuMu Android, enable ADB local connection in MuMu settings, then rerun this script."
    }
}

Invoke-Adb connect $Serial | Out-Null
Assert-DeviceConnected
Invoke-Adb -s $Serial shell settings put global http_proxy ":0"
Invoke-Adb -s $Serial shell settings delete global global_http_proxy_host
Invoke-Adb -s $Serial shell settings delete global global_http_proxy_port
Invoke-Adb -s $Serial shell settings delete global global_http_proxy_exclusion_list

Write-Host "MuMu Android proxy cleared."
