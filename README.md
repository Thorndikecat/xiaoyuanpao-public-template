# MuMu Route GPS Template

Windows PowerShell tools for playing a GPS route into MuMu Android Emulator through ADB. The repository is a public-safe template: it contains no real routes, APKs, account data, proxy subscriptions, emulator IDs, or log files.

Use this only for development, map testing, QA, demos, or accounts and apps you are authorized to test.

## What Is Included

- `mumu-route-gps.ps1`: main route playback script.
- `run-example-route-6km.ps1`: example 6 km loop runner.
- `pause-mumu-route.ps1` and `resume-mumu-route.ps1`: pause/resume controls.
- `mumu-use-pc-proxy.ps1` and `mumu-clear-proxy.ps1`: optional Android system proxy helpers.
- `routes/example-route.csv` and `routes/example-route.gpx`: demo coordinates only.

## What Is Not Included

Do not commit these files to a public repo:

- Real route CSV/GPX files.
- APKs, installers, or app packages.
- MuMu VM files, especially `vm_config.json`.
- Proxy subscriptions, Clash profiles, node URLs, tokens, cookies, or credentials.
- Logcat logs, screenshots, or recordings that include accounts, schools, routes, or location history.
- Keystores, certificates, and private keys.

The `.gitignore` is configured to keep common sensitive files out of the repo.

## MuMu Configuration

Required MuMu settings:

1. Start MuMu and wait until Android is fully booted.
2. Open MuMu device settings.
3. Enable developer options.
4. Enable ADB debugging / local ADB connection.
5. Confirm the ADB serial. The default used by these scripts is:

```text
127.0.0.1:16384
```

If your MuMu instance uses another ADB port, pass it explicitly:

```powershell
.\mumu-route-gps.ps1 -Serial 127.0.0.1:<PORT>
```

You can usually find the MuMu ADB port in the local MuMu `vm_config.json`, but do not commit that file because it may contain local device identifiers and emulator configuration.

The default MuMu ADB executable path is:

```text
D:\Program Files\Netease\MuMu\nx_device\12.0\shell\adb.exe
```

If your installation path is different, pass `-AdbPath`.

Root is not required for route playback. Writable system disk is not required for route playback. They may be useful for unrelated Android system modifications, but this template does not depend on them.

## Optional Proxy Configuration

In Android emulators, `10.0.2.2` means the Windows host machine. If your PC proxy listens on port `7897`, this command sets Android's system proxy to `10.0.2.2:7897`:

```powershell
.\mumu-use-pc-proxy.ps1
```

Clear the Android proxy:

```powershell
.\mumu-clear-proxy.ps1
```

Check current Android proxy:

```powershell
& "D:\Program Files\Netease\MuMu\nx_device\12.0\shell\adb.exe" -s 127.0.0.1:16384 shell settings get global http_proxy
```

Some Android apps ignore the system proxy. For those apps, use the emulator without proxy for domestic services, or use a proper TUN/transparent proxy setup on the host.

## Run The Example Route

Open PowerShell in this repository:

```powershell
cd <repo>
.\run-example-route-6km.ps1
```

The example runner:

- Uses `routes/example-route.csv`.
- Sends updates every 1 second.
- Randomizes speed per segment.
- Targets an average pace of about 6.5 min/km.
- Loops until total distance reaches 6 km.
- Writes both `gps` and `network` mock providers.

Stop manually:

```text
Ctrl+C
```

Pause:

```powershell
.\pause-mumu-route.ps1
```

Resume:

```powershell
.\resume-mumu-route.ps1
```

## Custom Routes

CSV format:

```csv
lat,lon,speed_kmh
31.230400,121.473700,9
31.230780,121.474180,10
31.231180,121.473640,8
```

`lat` is latitude. `lon` is longitude. `speed_kmh` is optional unless `-RandomSpeed` is not used.

Run a custom route:

```powershell
.\mumu-route-gps.ps1 -Route .\routes\private\my-route.csv -RandomSpeed -TargetPaceMinKm 6.5 -MaxDistanceKm 6 -Provider "gps", "network" -KeepProvider
```

Keep real routes in `routes/private/`; it is ignored by Git.

## Coordinate Systems

Android location APIs expect WGS84 coordinates.

Common map providers may use other coordinate systems:

- Baidu Maps: usually BD-09.
- Amap/Gaode: usually GCJ-02.
- Android GPS/mock location: WGS84.

Convert coordinates before playing them into Android, otherwise the route may appear shifted by hundreds of meters.

## Speed Model

With `-RandomSpeed`, each route segment gets a randomized pace. When `-TargetPaceMinKm` is set, the script applies a small correction based on the average pace generated so far.

Example:

```powershell
-RandomSpeed `
-TargetPaceMinKm 6.5 `
-PaceJitterMinKm 2.5 `
-MinPaceMinKm 4 `
-MaxPaceMinKm 9
```

This keeps each segment random while pulling the overall average toward about 6.5 min/km.
