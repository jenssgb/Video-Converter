<#
.SYNOPSIS
  YouTube → Audio/Video Converter (Win10/11)

.DESCRIPTION
  • Hebt sich selbst auf erhöhte Rechte (Admin) an  
  • Installiert/aktualisiert yt-dlp & ffmpeg via Chocolatey  
  • Fragt nach YouTube-URL  
  • Zeigt Fortschritts-Balken beim Download (yt-dlp)  
  • Ermittelt Dauer und zeigt Fortschritts-Balken beim Transcodieren (ffmpeg)  
  • Speichert fertige Datei im Desktop-Ordner YouTubeConverter  
  • Öffnet den Ziel-Ordner automatisch  
#>

# — Self-Elevation auf Admin —
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
     ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Erhebe Rechte auf Administrator…" -ForegroundColor Yellow
    Start-Process pwsh "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# — Ziel-Ordner auf dem Desktop anlegen/wechseln —
$desktop   = [Environment]::GetFolderPath('Desktop')
$baseDir   = Join-Path $desktop 'YouTubeConverter'
New-Item -ItemType Directory -Path $baseDir -Force | Out-Null
Set-Location $baseDir

# — 1) Installation & Update —
Write-Host "Installiere/aktualisiere yt-dlp & ffmpeg…" -ForegroundColor Cyan
choco install  yt-dlp ffmpeg -y    > $null 2>&1
choco upgrade yt-dlp ffmpeg -y     > $null 2>&1

# — 2) YouTube-URL abfragen —
$Url = Read-Host 'Bitte YouTube-URL eingeben'

# — 3) Download mit Fortschritts-Balken —
Write-Host "`nStarte Download…" -ForegroundColor Cyan
& yt-dlp.exe --newline -f bestvideo+bestaudio -o "%(title)s.%(ext)s" $Url 2>&1 |
  ForEach-Object {
    if ($_ -match '\[download\]\s+(\d+\.\d+)%') {
      $p = [int]$matches[1]
      Write-Progress -Activity 'Download' -Status "$p% komplett" -PercentComplete $p
    }
  }
Write-Progress -Activity 'Download' -Completed

# — 4) Eingabedatei ermitteln —
$input = Get-ChildItem -Path $baseDir -File |
         Sort-Object CreationTime -Descending |
         Select-Object -First 1

# — 5) Transcodieren mit Fortschritts-Balken —
Write-Host "`nStarte Transcoding…" -ForegroundColor Cyan
# Gesamtdauer in Sekunden abfragen
$totalSec = [double](& ffprobe.exe -v error -show_entries format=duration -of default=nw=1:nk=1 $input.FullName)

& ffmpeg.exe -i $input.FullName `
    -c:v libx264 -b:v 1800k -vf "scale=iw*0.5:ih*0.5,fps=24" `
    -c:a mp2   -b:a 320k -ac 2 -ar 48000 `
    -progress pipe:1 -nostats "_Converted_$($input.BaseName).mp4" |
  ForEach-Object {
    if ($_ -match 'out_time_ms=(\d+)') {
      $done = [int]$matches[1] / 1e6
      $percent = [int]($done / $totalSec * 100)
      Write-Progress -Activity 'Transcoding' -Status "$percent% komplett" -PercentComplete $percent
    }
  }
Write-Progress -Activity 'Transcoding' -Completed

# — 6) Aufräumen & Verschieben —
Remove-Item $input.FullName -Force
$output = Get-ChildItem -Path $baseDir -Filter "_Converted_*" | Select-Object -First 1
Move-Item $output.FullName $baseDir -Force

# — 7) Fertig & Explorer öffnen —
Write-Host "`nFertig! Öffne Ausgabe-Ordner…" -ForegroundColor Green
Invoke-Item $baseDir
