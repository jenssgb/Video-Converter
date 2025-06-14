# 🛡️ 1. Admin-Rechte prüfen und bei Bedarf neu starten
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
    [Security.Principal.WindowsBuiltInRole] "Administrator")) {
    
    Write-Host "Script wird mit Admin-Rechten neu gestartet..."
    Start-Process powershell -Verb runAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

# 🧰 2. Chocolatey installieren (falls noch nicht da)
if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host "Chocolatey wird installiert..."
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
}

# 📦 3. Python, ffmpeg, VLC installieren
choco install -y python ffmpeg vlc

# 📁 4. Zielordner 'YT-Downloads' auf Desktop anlegen
$desktop = [Environment]::GetFolderPath("Desktop")
$outputFolder = "$desktop\YT-Downloads"
if (!(Test-Path $outputFolder)) {
    New-Item -ItemType Directory -Path $outputFolder | Out-Null
}

# 🌐 5. Python-App herunterladen
$scriptUrl = "https://deine-domain.de/yt-downloader.py"  # <- HIER ANPASSEN
$scriptPath = "$outputFolder\yt-downloader.py"

Write-Host "Lade Python-Skript herunter..."
Invoke-WebRequest -Uri $scriptUrl -OutFile $scriptPath -UseBasicParsing

# ▶️ 6. Python-Skript ausführen
Write-Host "Starte Python-App..."
Start-Process "python" -ArgumentList "`"$scriptPath`""
