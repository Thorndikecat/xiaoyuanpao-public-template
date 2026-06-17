# MuMu 模拟定位轨迹模板

这是一个用于 MuMu 安卓模拟器的 GPS 轨迹播放模板。脚本在 Windows PowerShell 中运行，通过 MuMu 自带 ADB 向安卓系统持续写入模拟定位点。

这个仓库是公开安全版本：不包含真实路线、APK、账号信息、代理订阅、模拟器设备标识、日志文件或历史敏感提交。

请仅用于开发测试、地图调试、质量验证、演示，或你有权限控制的账号和应用场景。

## 仓库内容

- `mumu-route-gps.ps1`：主轨迹播放脚本。
- `run-example-route-6km.ps1`：示例 6 公里循环脚本。
- `pause-mumu-route.ps1` / `resume-mumu-route.ps1`：暂停和继续当前轨迹。
- `mumu-use-pc-proxy.ps1` / `mumu-clear-proxy.ps1`：可选的安卓系统代理开关脚本。
- `routes/example-route.csv` / `routes/example-route.gpx`：演示路线坐标。
- `docs/security.md`：公开仓库安全注意事项。

## 不应上传的内容

不要把下面这些内容提交到公开仓库：

- 真实路线 CSV / GPX。
- APK、安装包、应用备份。
- MuMu 虚拟机配置，尤其是 `vm_config.json`。
- 代理订阅、Clash 配置、节点 URL、token、cookie、账号密码。
- logcat 日志、截图、录屏，尤其是包含账号、学校、路线或定位历史的文件。
- 签名证书、keystore、私钥。

仓库里的 `.gitignore` 已经排除了常见敏感文件，但不要只依赖 `.gitignore`。提交前仍应检查 `git status` 和即将提交的文件列表。

## MuMu 配置

运行脚本前需要完成这些设置：

1. 启动 MuMu，等待安卓桌面完全进入。
2. 打开 MuMu 设备设置。
3. 开启开发者选项。
4. 开启 ADB 调试 / 本地 ADB 连接。
5. 确认 ADB 连接端口。

脚本默认使用的 ADB 设备地址是：

```text
127.0.0.1:16384
```

如果你的 MuMu 实例使用其他端口，运行时显式传入：

```powershell
.\mumu-route-gps.ps1 -Serial 127.0.0.1:<端口>
```

通常可以在本机 MuMu 的 `vm_config.json` 中查看 ADB 端口，但不要把这个文件上传到公开仓库，因为它可能包含本机路径、设备标识和模拟器配置。

脚本默认的 MuMu ADB 路径是：

```text
D:\Program Files\Netease\MuMu\nx_device\12.0\shell\adb.exe
```

如果你的安装路径不同，运行时传入 `-AdbPath`。

轨迹播放不需要 Root，也不需要可写系统盘。Root 或可写系统盘只和其他安卓系统改动有关，本模板不依赖它们。

## 检查 ADB 连接

```powershell
& "D:\Program Files\Netease\MuMu\nx_device\12.0\shell\adb.exe" connect 127.0.0.1:16384
& "D:\Program Files\Netease\MuMu\nx_device\12.0\shell\adb.exe" devices
```

正常情况下应看到：

```text
127.0.0.1:16384    device
```

如果设备没有出现，先确认 MuMu 安卓桌面已启动，并检查 MuMu 设置里的 ADB 本地连接是否开启。

## 可选代理配置

在安卓模拟器中，`10.0.2.2` 表示宿主 Windows 电脑。

如果电脑代理监听 `7897` 端口，可以把安卓系统代理设置为 `10.0.2.2:7897`：

```powershell
.\mumu-use-pc-proxy.ps1
```

清除安卓系统代理：

```powershell
.\mumu-clear-proxy.ps1
```

查看当前安卓代理：

```powershell
& "D:\Program Files\Netease\MuMu\nx_device\12.0\shell\adb.exe" -s 127.0.0.1:16384 shell settings get global http_proxy
```

部分安卓应用不会遵守系统代理。对于国内服务，通常建议关闭模拟器代理；对于必须走代理的服务，可以使用宿主机 TUN / 透明代理方案。

## 运行示例路线

在 PowerShell 中进入仓库目录：

```powershell
cd <仓库目录>
.\run-example-route-6km.ps1
```

示例脚本行为：

- 使用 `routes/example-route.csv`。
- 每 1 秒写入一次定位点。
- 每段随机速度。
- 目标平均配速约为 `6.5 分/公里`。
- 路线循环，累计到 6 公里后自动停止。
- 同时写入 `gps` 和 `network` 两个模拟定位 provider。

手动停止：

```text
Ctrl+C
```

暂停：

```powershell
.\pause-mumu-route.ps1
```

继续：

```powershell
.\resume-mumu-route.ps1
```

## 自定义路线

CSV 格式：

```csv
lat,lon,speed_kmh
31.230400,121.473700,9
31.230780,121.474180,10
31.231180,121.473640,8
```

字段说明：

- `lat`：纬度。
- `lon`：经度。
- `speed_kmh`：从当前点到下一个点的速度，单位为公里/小时。使用 `-RandomSpeed` 时可不依赖这个字段。

运行自定义路线：

```powershell
.\mumu-route-gps.ps1 `
    -Route .\routes\private\my-route.csv `
    -RandomSpeed `
    -TargetPaceMinKm 6.5 `
    -MaxDistanceKm 6 `
    -Provider "gps", "network" `
    -KeepProvider
```

真实路线建议放在：

```text
routes/private/
```

这个目录已被 `.gitignore` 忽略，不会被提交到公开仓库。

## 坐标系

安卓定位接口期望 WGS84 坐标。

常见地图坐标系：

- 百度地图：通常是 BD-09。
- 高德地图：通常是 GCJ-02。
- 安卓 GPS / mock location：WGS84。

如果直接把百度或高德坐标写入安卓定位，路线可能整体偏移几十到几百米。应先转换成 WGS84。

## 速度模型

使用 `-RandomSpeed` 时，脚本会为路线中的每一段随机生成配速。

如果设置了 `-TargetPaceMinKm`，脚本会根据前面已经生成的平均配速做轻微纠偏，让整体平均更接近目标值。

示例：

```powershell
-RandomSpeed `
-TargetPaceMinKm 6.5 `
-PaceJitterMinKm 2.5 `
-MinPaceMinKm 4 `
-MaxPaceMinKm 9
```

含义：

- 单段配速在 `4-9 分/公里` 内浮动。
- 每段速度随机。
- 整体平均尽量靠近 `6.5 分/公里`。

## 发布前检查

公开发布前建议执行：

```powershell
git status --short --ignored
git diff --cached --name-only
```

确认没有真实路线、APK、日志、截图、账号信息、代理配置或 MuMu 本地配置文件进入提交。
