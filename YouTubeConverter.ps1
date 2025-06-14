<#
.SYNOPSIS
  YouTubeConverter Watch & Convert (Win10/11): überwacht urls.txt im Editor und verarbeitet neue Links automatisch

.DESCRIPTION
  • Hebt sich selbst auf Admin-Rechte an
  • Installiert Chocolatey (falls nötig) und stellt choco.exe in der Session bereit
  • Installiert/updatet yt-dlp & ffmpeg via Chocolatey
  • Legt Desktop\YouTubeConverter und urls.txt an (falls nötig)
  • Öffnet urls.txt im Notepad
  • Überwacht Dateiänderungen via FileSystemWatcher
  • Für jede neue URL (Zeilen ohne "-->"):
      - Download mit Fortschritts-Balken
      - Transcoding mit Fortschritts-Balken
      - Hängt "--> Download OK --> Transcode OK" an die Zeile an
#>
param(
    [switch]$Watch = $true
)

# --- 1) Admin Self-Elevation ---
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
     ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process pwsh "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# --- 2) Chocolatey Bootstrap & Pfad ---
$chocoRoot = Join-Path $env:ProgramData 'chocolatey'
$chocoExe  = Join-Path $chocoRoot 'bin\choco.exe'
if (-not (Test-Path $chocoExe)) {
    Write-Host "Chocolatey wird installiert..." -ForegroundColor Cyan
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    iex ((New-Object Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
}
# Session-PATH aktualisieren
$env:Path += ";$chocoRoot\bin"

# --- 3) Setup Desktop-Ordner & urls.txt ---
$desktop = [Environment]::GetFolderPath('Desktop')
$baseDir = Join-Path $desktop 'YouTubeConverter'
if (!(Test-Path $baseDir)) { New-Item -ItemType Directory -Path $baseDir | Out-Null }
Set-Location $baseDir

$urlsFile = Join-Path $baseDir 'urls.txt'
if (!(Test-Path $urlsFile)) {
    "# Füge hier YouTube-URLs ein, jeweils eine pro Zeile" | Out-File $urlsFile -Encoding UTF8
}

# --- 4) Install/Update Dependencies ---
Write-Host "Installiere/aktualisiere yt-dlp & ffmpeg..." -ForegroundColor Cyan
& $chocoExe install yt-dlp ffmpeg -y > $null 2>&1
& $chocoExe upgrade yt-dlp ffmpeg -y  > $null 2>&1

# --- 5) Processing Function ---
function Process-Urls {
    $lines = Get-Content $urlsFile
    $updated = $false
    for ($i = 0; $i -lt $lines.Length; $i++) {
        $line = $lines[$i].Trim()
        if ($line -and $line -notmatch '-->') {
            Write-Host "\nVerarbeite: $line" -ForegroundColor Magenta
            # Download mit Fortschritt
            Write-Host "Download..." -ForegroundColor Cyan
            & yt-dlp.exe --newline -f bestvideo+bestaudio -o "% (title)s.%(ext)s" $line 2>&1 |
              ForEach-Object {
                if ($_ -match '\[download\]\s+(\d+\.\d+)%') {
                  Write-Progress -Activity 'Download' -Status "$($matches[1])%" -PercentComplete ([int]$matches[1])
                }
              }
            Write-Progress -Activity 'Download' -Completed

            # Transcoding mit Fortschritt
            $latest = Get-ChildItem -File | Sort CreationTime -Descending | Select -First 1
            $dur = [double](& ffprobe.exe -v error -show_entries format=duration -of default=nw=1:nk=1 $latest.FullName)
            Write-Host "Transcode..." -ForegroundColor Cyan
            & ffmpeg.exe -i $latest.FullName `
              -c:v libx264 -b:v 1800k -vf "scale=iw*0.5:ih*0.5,fps=24" `
              -c:a mp2 -b:a 320k -ac 2 -ar 48000 `
              -progress pipe:1 -nostats "_Converted_$($latest.BaseName).mp4" |
              ForEach-Object {
                if ($_ -match 'out_time_ms=(\d+)') {
                  $pct = [int](([int]$matches[1] / 1e6) / $dur * 100)
                  Write-Progress -Activity 'Transcoding' -Status "$pct%" -PercentComplete $pct
                }
              }
            Write-Progress -Activity 'Transcoding' -Completed

            # Status anhängen
            $lines[$i] = "$line --> Download OK --> Transcode OK"
            $updated = $true
        }
    }
    if ($updated) { $lines | Set-Content $urlsFile -Encoding UTF8 }
}

# --- 6) Watch-Modus starten ---
Write-Host "Starte Watch-Modus. Öffne urls.txt im Editor..." -ForegroundColor Green
Start-Process notepad.exe $urlsFile
$fsw = New-Object IO.FileSystemWatcher $baseDir, 'urls.txt'
$fsw.NotifyFilter = [IO.NotifyFilters]'LastWrite'
$fsw.EnableRaisingEvents = $true
Register-ObjectEvent $fsw Changed -SourceIdentifier UrlFileChanged -Action {
    Start-Sleep -Seconds 1
    Process-Urls
}
# Initiale Verarbeitung
Process-Urls
# Warte auf Änderungen
while ($true) { Wait-Event -SourceIdentifier UrlFileChanged | Out-Null }
