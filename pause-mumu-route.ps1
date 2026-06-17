$pauseFile = Join-Path $PSScriptRoot "mumu-route.pause"
Set-Content -LiteralPath $pauseFile -Value ("paused_at=" + (Get-Date).ToString("o")) -Encoding ASCII
Write-Host "Pause requested."
Write-Host "The route will hold at the current position on the next update."
