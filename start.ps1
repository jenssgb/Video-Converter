# ====================================================================================
# BluePolicy App-Installer für Windows
# ====================================================================================

# 1. Adminrechte prüfen und ggf. Script mit Adminrechten neu starten
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "🛡️ Script wird mit Adminrechten neu gestartet..."
    Start-Process powershell -Verb runAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

# 2. Logging starten
$log = "$env:TEMP\yt-setup-log.txt"
Start-Transcript -Path $log -Append

try {
    Write-Host "VERSION 1.0"
    Write-Host "📦 Setup gestartet..."

    # 3. Chocolatey installieren, falls nicht vorhanden
    if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Host "🍫 Chocolatey wird installiert..."
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    }

    # 4. Python, ffmpeg, VLC updaten oder installieren
    Write-Host "🔄 Aktualisiere oder installiere python, ffmpeg, vlc..."
    choco upgrade -y python ffmpeg vlc --install-if-not-installed

    # 5. Ausgabeordner auf Desktop anlegen
    $desktop = [Environment]::GetFolderPath("Desktop")
    $outputFolder = Join-Path $desktop "YT-Downloads"
    if (!(Test-Path $outputFolder)) {
        New-Item -ItemType Directory -Path $outputFolder | Out-Null
        Write-Host "📁 Ordner erstellt: $outputFolder"
    }

    # 6. Dateien aus GitHub laden
    $files = @(
        @{ Name = "app.py";           Url = "https://raw.githubusercontent.com/jenssgb/Video-Converter/main/app.py" },
        @{ Name = "requirements.txt"; Url = "https://raw.githubusercontent.com/jenssgb/Video-Converter/main/requirements.txt" }
    )

    foreach ($file in $files) {
        $targetPath = Join-Path $outputFolder $file.Name
        Write-Host "🌐 Lade $($file.Name)..."
        Invoke-WebRequest -Uri $file.Url -OutFile $targetPath -UseBasicParsing
    }

    # 7. Python-Abhängigkeiten installieren (über direkten Pfad)
    $pythonExe = "$env:ProgramData\chocolatey\lib\python\tools\python.exe"
    $reqFile = Join-Path $outputFolder "requirements.txt"

    if (Test-Path $pythonExe) {
        Write-Host "📦 Installiere Python-Abhängigkeiten..."
        & "$pythonExe" -m pip install --upgrade pip
        & "$pythonExe" -m pip install -r "`"$reqFile`""

        # 8. app.py starten
        $appPath = Join-Path $outputFolder "app.py"
        Write-Host "▶️ Starte app.py..."
        Start-Process "$pythonExe" -ArgumentList "`"$appPath`""
    } else {
        Write-Host "❌ Python wurde nicht gefunden unter: $pythonExe"
    }

} catch {
    Write-Host "❌ FEHLER: $_"
}

Stop-Transcript

# 9. Fenster offen halten
Write-Host "`n✅ Setup abgeschlossen. Log-Datei: $log"
Read-Host -Prompt "Drücke Enter zum Beenden"
