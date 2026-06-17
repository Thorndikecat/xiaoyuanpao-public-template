param(
    [string]$Route = ".\routes\example-route.csv",
    [double]$SpeedKmh = 12,
    [double]$IntervalSeconds = 1,
    [string]$Serial = "127.0.0.1:16384",
    [string]$AdbPath = "D:\Program Files\Netease\MuMu\nx_device\12.0\shell\adb.exe",
    [string[]]$Provider = @("gps", "network", "fused"),
    [double]$AccuracyMeters = 5,
    [double]$MaxDistanceKm = 0,
    [switch]$RandomSpeed,
    [double]$TargetPaceMinKm = 0,
    [double]$PaceJitterMinKm = 2,
    [double]$MinPaceMinKm = 3,
    [double]$MaxPaceMinKm = 9.9,
    [string]$PauseFile = "",
    [double]$PauseRefreshSeconds = 2,
    [switch]$Loop,
    [switch]$KeepProvider
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-Adb {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Args)
    & $AdbPath -s $Serial @Args
    if ($LASTEXITCODE -ne 0) {
        throw "adb command failed: $($Args -join ' ')"
    }
}

function Get-HaversineMeters {
    param(
        [double]$Lat1,
        [double]$Lon1,
        [double]$Lat2,
        [double]$Lon2
    )
    $radius = 6371000.0
    $toRad = [Math]::PI / 180.0
    $dLat = ($Lat2 - $Lat1) * $toRad
    $dLon = ($Lon2 - $Lon1) * $toRad
    $a = [Math]::Sin($dLat / 2) * [Math]::Sin($dLat / 2) +
        [Math]::Cos($Lat1 * $toRad) * [Math]::Cos($Lat2 * $toRad) *
        [Math]::Sin($dLon / 2) * [Math]::Sin($dLon / 2)
    return 2 * $radius * [Math]::Atan2([Math]::Sqrt($a), [Math]::Sqrt(1 - $a))
}

function Read-RoutePoints {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Route file not found: $Path"
    }

    $extension = [IO.Path]::GetExtension($Path).ToLowerInvariant()
    if ($extension -eq ".gpx") {
        [xml]$xml = Get-Content -LiteralPath $Path -Raw
        $nodes = $xml.SelectNodes("//*[local-name()='trkpt' or local-name()='rtept' or local-name()='wpt']")
        if ($nodes.Count -eq 0) {
            throw "No trkpt/rtept/wpt nodes found in GPX: $Path"
        }

        return @($nodes | ForEach-Object {
            [pscustomobject]@{
                Lat = [double]$_.lat
                Lon = [double]$_.lon
                SpeedKmh = $null
            }
        })
    }

    $rows = Import-Csv -LiteralPath $Path
    $points = @($rows | ForEach-Object {
        $lat = if ($_.lat) { $_.lat } elseif ($_.latitude) { $_.latitude } else { throw "CSV needs lat/lon columns." }
        $lon = if ($_.lon) { $_.lon } elseif ($_.lng) { $_.lng } elseif ($_.longitude) { $_.longitude } else { throw "CSV needs lat/lon columns." }
        $rowSpeed = $null
        if ($_.PSObject.Properties.Name -contains "speed_kmh" -and $_.speed_kmh) {
            $rowSpeed = [double]$_.speed_kmh
        }

        [pscustomobject]@{
            Lat = [double]$lat
            Lon = [double]$lon
            SpeedKmh = $rowSpeed
        }
    })

    if ($points.Count -lt 2) {
        throw "Route needs at least two points."
    }

    return $points
}

function Set-TestLocation {
    param(
        [double]$Lat,
        [double]$Lon,
        [string[]]$Providers
    )
    $location = "{0:F7},{1:F7}" -f $Lat, $Lon
    $timeMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    foreach ($providerName in $Providers) {
        Invoke-Adb shell cmd location providers set-test-provider-location $providerName --location $location --accuracy $AccuracyMeters --time $timeMs | Out-Null
    }
}

function Wait-IfPaused {
    param(
        [double]$Lat,
        [double]$Lon,
        [string[]]$Providers
    )

    if (-not (Test-Path -LiteralPath $PauseFile)) {
        return 0.0
    }

    Write-Host ("Paused at {0:F6},{1:F6}. Run resume-mumu-route.ps1 to continue." -f $Lat, $Lon)
    $pauseClock = [Diagnostics.Stopwatch]::StartNew()
    while (Test-Path -LiteralPath $PauseFile) {
        Set-TestLocation -Lat $Lat -Lon $Lon -Providers $Providers
        Start-Sleep -Milliseconds ([int]($PauseRefreshSeconds * 1000))
    }
    Write-Host "Resumed."
    return $pauseClock.Elapsed.TotalSeconds
}

if (-not (Test-Path -LiteralPath $AdbPath)) {
    throw "MuMu adb not found: $AdbPath"
}

if ($MaxDistanceKm -lt 0) {
    throw "MaxDistanceKm must be 0 or greater."
}

if ($MinPaceMinKm -le 0 -or $MaxPaceMinKm -le 0 -or $MinPaceMinKm -gt $MaxPaceMinKm) {
    throw "Pace range must be positive, and MinPaceMinKm must be less than or equal to MaxPaceMinKm."
}

if ($TargetPaceMinKm -lt 0) {
    throw "TargetPaceMinKm must be 0 or greater."
}

if ($TargetPaceMinKm -gt 0 -and ($TargetPaceMinKm -lt $MinPaceMinKm -or $TargetPaceMinKm -gt $MaxPaceMinKm)) {
    throw "TargetPaceMinKm must be inside the MinPaceMinKm/MaxPaceMinKm range."
}

if ($PaceJitterMinKm -lt 0) {
    throw "PaceJitterMinKm must be 0 or greater."
}

if ($PauseRefreshSeconds -le 0) {
    throw "PauseRefreshSeconds must be greater than 0."
}

if (-not $PauseFile) {
    $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
    $PauseFile = Join-Path $scriptDir "mumu-route.pause"
}

$random = [System.Random]::new()

$resolvedRoute = (Resolve-Path -LiteralPath $Route).Path
$points = Read-RoutePoints -Path $resolvedRoute
$Provider = @(
    $Provider |
        ForEach-Object { $_ -split "," } |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ }
)

if ($Provider.Count -eq 0) {
    throw "At least one location provider is required."
}

& $AdbPath connect $Serial | Out-Null
# Android's location shell command must run as the normal shell user. MuMu may
# stay in rooted ADB mode after system-file work, so switch it back quietly.
& $AdbPath -s $Serial unroot | Out-Null
Start-Sleep -Milliseconds 800
& $AdbPath connect $Serial | Out-Null
Invoke-Adb shell settings put global development_settings_enabled 1
Invoke-Adb shell settings put secure development_settings_enabled 1
Invoke-Adb shell settings put secure mock_location 1
Invoke-Adb shell cmd appops set com.android.shell android:mock_location allow
Invoke-Adb shell cmd location set-location-enabled true

try {
    foreach ($providerName in $Provider) {
        Invoke-Adb shell cmd location providers remove-test-provider $providerName 2>$null
    }
} catch {
    # Fine when the provider was not previously mocked.
}

$activeProviders = @()
foreach ($providerName in $Provider) {
    try {
        Invoke-Adb shell cmd location providers add-test-provider $providerName --supportsSpeed --supportsBearing --supportsAltitude
        Invoke-Adb shell cmd location providers set-test-provider-enabled $providerName true
        $activeProviders += $providerName
    } catch {
        Write-Host "Provider unavailable, skipped: $providerName"
    }
}

if ($activeProviders.Count -eq 0) {
    throw "No mock location provider could be enabled."
}

Write-Host "MuMu route playback started."
Write-Host "Route: $resolvedRoute"
Write-Host "Providers: $($activeProviders -join ', ')"
Write-Host "Pause file: $PauseFile"
if ($RandomSpeed) {
    if ($TargetPaceMinKm -gt 0) {
        Write-Host "Random pace target: avg ~$TargetPaceMinKm min/km, jitter +/-$PaceJitterMinKm, clamp $MinPaceMinKm-$MaxPaceMinKm min/km, interval: $IntervalSeconds s"
    } else {
        Write-Host "Random pace: $MinPaceMinKm-$MaxPaceMinKm min/km, interval: $IntervalSeconds s"
    }
} else {
    Write-Host "Default speed: $SpeedKmh km/h, interval: $IntervalSeconds s"
}
if ($MaxDistanceKm -gt 0) {
    Write-Host "Route will loop until total distance reaches $MaxDistanceKm km."
}
Write-Host "Press Ctrl+C to stop."

$maxDistanceMeters = if ($MaxDistanceKm -gt 0) { $MaxDistanceKm * 1000.0 } else { [double]::PositiveInfinity }
$totalDistanceMeters = 0.0
$lastLat = $null
$lastLon = $null
$stopForDistance = $false
$lap = 1
$shouldLoop = $Loop -or ($MaxDistanceKm -gt 0)
$plannedDistanceMeters = 0.0
$plannedTimeSeconds = 0.0

try {
    do {
        Write-Host "Lap $lap started."
        for ($i = 0; $i -lt ($points.Count - 1); $i++) {
            if ($stopForDistance) {
                break
            }

            $from = $points[$i]
            $to = $points[$i + 1]
            if ($RandomSpeed) {
                if ($TargetPaceMinKm -gt 0) {
                    $randomOffset = (($random.NextDouble() * 2.0) - 1.0) * $PaceJitterMinKm
                    $averageCorrection = 0.0
                    if ($plannedDistanceMeters -gt 1.0) {
                        $currentAveragePace = ($plannedTimeSeconds / 60.0) / ($plannedDistanceMeters / 1000.0)
                        $averageCorrection = ($TargetPaceMinKm - $currentAveragePace) * 0.75
                    }
                    $segmentPace = $TargetPaceMinKm + $randomOffset + $averageCorrection
                    $segmentPace = [Math]::Min($MaxPaceMinKm, [Math]::Max($MinPaceMinKm, $segmentPace))
                } else {
                    $segmentPace = $MinPaceMinKm + ($random.NextDouble() * ($MaxPaceMinKm - $MinPaceMinKm))
                }
                $segmentSpeed = 60.0 / $segmentPace
            } else {
                $segmentSpeed = if ($null -ne $from.SpeedKmh -and $from.SpeedKmh -gt 0) { $from.SpeedKmh } else { $SpeedKmh }
                $segmentPace = 60.0 / $segmentSpeed
            }
            $metersPerSecond = [Math]::Max($segmentSpeed / 3.6, 0.1)
            $distance = Get-HaversineMeters -Lat1 $from.Lat -Lon1 $from.Lon -Lat2 $to.Lat -Lon2 $to.Lon
            $durationSeconds = $distance / $metersPerSecond
            $steps = [Math]::Max(1, [int][Math]::Ceiling($durationSeconds / $IntervalSeconds))
            $plannedDistanceMeters += $distance
            $plannedTimeSeconds += $durationSeconds

            for ($step = 0; $step -le $steps; $step++) {
                if ($stopForDistance) {
                    break
                }

                $ratio = $step / $steps
                $lat = $from.Lat + (($to.Lat - $from.Lat) * $ratio)
                $lon = $from.Lon + (($to.Lon - $from.Lon) * $ratio)

                if ($null -ne $lastLat) {
                    $incrementMeters = Get-HaversineMeters -Lat1 $lastLat -Lon1 $lastLon -Lat2 $lat -Lon2 $lon
                    if (($totalDistanceMeters + $incrementMeters) -ge $maxDistanceMeters) {
                        $remainingMeters = [Math]::Max(0.0, $maxDistanceMeters - $totalDistanceMeters)
                        $finalRatio = if ($incrementMeters -gt 0) { $remainingMeters / $incrementMeters } else { 0.0 }
                        $lat = $lastLat + (($lat - $lastLat) * $finalRatio)
                        $lon = $lastLon + (($lon - $lastLon) * $finalRatio)
                        $incrementMeters = $remainingMeters
                        $stopForDistance = $true
                    }
                    $totalDistanceMeters += $incrementMeters
                }

                Set-TestLocation -Lat $lat -Lon $lon -Providers $activeProviders
                $lastLat = $lat
                $lastLon = $lon

                Write-Host ("{0:HH:mm:ss} lap {1} point {2}/{3} segment {4}/{5} pace {6:N2} min/km speed {7:N1} km/h total {8:N3} km  {9:F6},{10:F6}" -f (Get-Date), $lap, ($step + 1), ($steps + 1), ($i + 1), ($points.Count - 1), $segmentPace, $segmentSpeed, ($totalDistanceMeters / 1000.0), $lat, $lon)

                if (-not $stopForDistance) {
                    Wait-IfPaused -Lat $lat -Lon $lon -Providers $activeProviders | Out-Null
                    Start-Sleep -Milliseconds ([int]($IntervalSeconds * 1000))
                }
            }
        }

        $lap++
    } while ($shouldLoop -and -not $stopForDistance)

    if ($stopForDistance) {
        Write-Host ("Reached max distance: {0:N3} km." -f ($totalDistanceMeters / 1000.0))
    }
} finally {
    if (-not $KeepProvider) {
        try {
            foreach ($providerName in $activeProviders) {
                Invoke-Adb shell cmd location providers remove-test-provider $providerName 2>$null
            }
            Write-Host "Mock provider removed."
        } catch {
            Write-Host "Unable to remove mock provider automatically. You can close MuMu or rerun with cleanup later."
        }
    }
}
