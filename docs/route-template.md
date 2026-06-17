# 路线设计模板

可以。公开模板里提供两类路线文件：

- `routes/route-template.csv`：给用户填写真实路径点的模板。
- `routes/example-route.csv`：可以直接运行的演示路线。

真实路线不要提交到公开仓库。建议复制模板到：

```text
routes/private/my-route.csv
```

`routes/private/` 已被 `.gitignore` 忽略。

## 填写格式

模板字段：

```csv
order,lat,lon,name,note
1,31.230400,121.473700,start,replace with your WGS84 point
2,31.230780,121.474180,checkpoint-1,replace with your WGS84 point
3,31.231180,121.473640,checkpoint-2,replace with your WGS84 point
4,31.230400,121.473700,end,close the loop if needed
```

字段说明：

- `order`：路径点顺序。
- `lat`：纬度。
- `lon`：经度。
- `name`：点位名称，可选。
- `note`：备注，可选。

实际播放脚本只需要 `lat` 和 `lon`。其他字段用于人工维护路线。

## 坐标要求

安卓模拟定位使用 WGS84 坐标。

如果点位来自百度地图，通常是 BD-09；如果来自高德地图，通常是 GCJ-02。使用前需要转换为 WGS84，否则路线会偏移。

## 运行用户路线

```powershell
.\mumu-route-gps.ps1 `
    -Route .\routes\private\my-route.csv `
    -RandomSpeed `
    -TargetPaceMinKm 6.5 `
    -MaxDistanceKm 6 `
    -Provider "gps", "network" `
    -KeepProvider
```

如果路线不是闭环，脚本循环时会从最后一个点直接回到第一个点。要避免这段跳线，可以把起点再填为最后一个点。

## 推荐点位数量

最少 2 个点即可运行。

实际路线建议：

- 简单直线：2-5 个点。
- 校园环线：10-40 个点。
- 需要贴合道路：在转弯、路口、入口、折返点添加点。

点越密，轨迹越贴合；点太密会增加维护成本。
