$pauseFile = Join-Path $PSScriptRoot "mumu-route.pause"
if (Test-Path -LiteralPath $pauseFile) {
    Remove-Item -LiteralPath $pauseFile -Force
    Write-Host "Resume requested."
} else {
    Write-Host "Route is not paused."
}
