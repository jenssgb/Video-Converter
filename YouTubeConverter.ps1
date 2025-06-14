<#
.SYNOPSIS
  YouTube → Audio/Video Converter (Win10/11) mit automatischem Choco-Bootstrap und PATH-Handling

.DESCRIPTION
  • Hebt sich selbst als Admin an  
  • Installiert Chocolatey, falls nicht vorhanden  
  • Sorgt dafür, dass choco.exe in der aktuellen Session verfügbar ist  
  • Installiert/updatet yt-dlp & ffmpeg über Chocolatey  
  • Download & Transcoding mit Progressbars  
  • Speichert auf dem Desktop in “YouTubeConverter”  
  • Öffnet den Ausgabe-Ordner  
#>

# 1) Self-Elevation auf Admin
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
     ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process pwsh "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# 2) Choco-Bootstrap (falls nicht installiert) und Choco-Pfad setzen
$chocoInstallRoot = Join-Path $env:ProgramData 'chocolatey'
$chocoPath = Join-Path $chocoInstallRoot 'bin\choco.exe'
if (-not (Test-Path $chocoPath)) {
    Write-Host "Chocolatey wird installiert…" -ForegroundColor Cyan
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
}

# 3) PATH für aktuelle Session aktualisieren
$machinePath = [System.Environment]::GetEnvironmentVariable('Path','Machine')
if ($machinePath -notmatch [Regex]::Escape($chocoInstallRoot + '\bin')) {
    # In seltenen Fällen kann der Pfad fehlen, stellen wir sicher, dass er da ist
    [System.Environment]::SetEnvironmentVariable('Path', "$machinePath;$chocoInstallRoot\bin", 'Machine')
    $env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine')
} else {
    # Pfad existiert global, aber Session kennt ihn noch nicht
    $env:Path += ";$chocoInstallRoot\bin"
}

# 4) Desktop-Ordner anlegen/wechseln
$desktop   = [Environment]::GetFolderPath('Desktop')
$baseDir   = Join-Path $desktop 'YouTubeConverter'
New-Item -ItemType Directory -Path $baseDir -Force | Out-Null
Set-Location $baseDir

# 5) Installation & Update per Choco-Pfad
Write-Host "Installiere/aktualisiere yt-dlp & ffmpeg…" -ForegroundColor Cyan
& $chocoPath install yt-dlp ffmpeg -y > $null 2>&1
& $chocoPath upgrade yt-dlp ffmpeg -y > $null 2>&1

# 6) YouTube-URL abfragen
$Url = Read-Host 'Bitte YouTube-URL eingeben'

# 7) Download mit Fortschritts-Balken
Write-Host "`nStarte Download…" -ForegroundColor Cyan
& yt-dlp.exe --newline -f bestvideo+bestaudio -o "%(title)s.%(ext)s" $Url 2>&1 |
  ForEach-Object {
    if ($_ -match '\[download\]\s+(\d+\.\d+)%') {
      $p = [int]$matches[1]
      Write-Progress -Activity 'Download' -Status "$p% komplett" -PercentComplete $p
    }
  }
Write-Progress -Activity 'Download' -Completed

# 8) Aktuellste Datei ermitteln
$input = Get-ChildItem -Path $baseDir -File |
         Sort-Object CreationTime -Descending |
         Select-Object -First 1

# 9) Transcodieren mit Fortschritts-Balken
Write-Host "`nStarte Transcoding…" -ForegroundColor Cyan
$totalSec = [double](& ffprobe.exe -v error -show_entries format=duration -of default=nw=1:nk=1 $input.FullName)

& ffmpeg.exe -i $input.FullName `
    -c:v libx264 -b:v 1800k -vf "scale=iw*0.5:ih*0.5,fps=24" `
    -c:a mp2 -b:a 320k -ac 2 -ar 48000 `
    -progress pipe:1 -nostats "_Converted_$($input.BaseName).mp4" |
  ForEach-Object {
    if ($_ -match 'out_time_ms=(\d+)') {
      $done = [int]$matches[1] / 1e6
      $percent = [int]($done / $totalSec * 100)
      Write-Progress -Activity 'Transcoding' -Status "$percent% komplett" -PercentComplete $percent
    }
  }
Write-Progress -Activity 'Transcoding' -Completed

# 10) Aufräumen & Verschieben
Remove-Item $input.FullName -Force
$output = Get-ChildItem -Path $baseDir -Filter "_Converted_*" | Select-Object -First 1
Move-Item $output.FullName $baseDir -Force

# 11) Fertig & Explorer öffnen
Write-Host "`nFertig! Öffne Ausgabe-Ordner…" -ForegroundColor Green
Invoke-Item $baseDir
