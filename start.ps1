# ====================================================================================
# BluePolicy Setup Script – VERSION 1.0 – by Jens
# ====================================================================================

# 1. Adminrechte prüfen
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "🛡️ Script wird mit Adminrechten neu gestartet..."
    Start-Process powershell -Verb runAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

# 2. Logging starten
$log = "$env:TEMP\yt-setup-log.txt"
Start-Transcript -Path $log -Append

Write-Host ""
Write-Host "🌐 BluePolicy App Setup gestartet – VERSION 1.1"
Write-Host "📄 Log-Datei: $log"
Write-Host ""

try {
    # 3. Chocolatey installieren
    if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Host "🍫 Chocolatey wird installiert..."
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    }

    # 4. Tools installieren oder updaten
    Write-Host "🔄 Prüfe Python, ffmpeg, VLC..."
    choco upgrade -y python ffmpeg vlc --install-if-not-installed

    # 5. Zielordner auf Desktop anlegen
    $desktop = [Environment]::GetFolderPath("Desktop")
    $outputFolder = Join-Path $desktop "YT-Downloads"
    if (!(Test-Path $outputFolder)) {
        New-Item -ItemType Directory -Path $outputFolder | Out-Null
        Write-Host "📁 Ordner erstellt: $outputFolder"
    }

    # 6. Dateien von GitHub laden
    $repoBase = "https://raw.githubusercontent.com/jenssgb/Video-Converter/main"
    $files = @(
        @{ Name = "app.py"; Url = "$repoBase/app.py" },
        @{ Name = "requirements.txt"; Url = "$repoBase/requirements.txt" },
        @{ Name = "VERSION"; Url = "$repoBase/VERSION" }
    )

    foreach ($file in $files) {
        $targetPath = Join-Path $outputFolder $file.Name
        Write-Host "🌐 Lade $($file.Name)..."
        Invoke-WebRequest -Uri $file.Url -OutFile $targetPath -UseBasicParsing
    }

    # 7. Versions-/Commit-Ausgabe (falls Datei vorhanden)
    $versionFile = Join-Path $outputFolder "VERSION"
    if (Test-Path $versionFile) {
        $versionText = Get-Content $versionFile | Select-Object -First 1
        Write-Host "`n🆔 Aktuelle App-Version / Commit-ID: $versionText`n"
    } else {
        Write-Host "`n⚠️ Keine VERSION-Datei gefunden – Commit-ID unbekannt.`n"
    }

    # 8. Python finden (über where.exe)
    $pythonExe = (& where.exe python 2>$null | Select-Object -First 1)

    if ([string]::IsNullOrEmpty($pythonExe) -or !(Test-Path $pythonExe)) {
        Write-Host "❌ Python konnte nicht gefunden werden. Ist es korrekt installiert?"
        Write-Host "   Versuche Neustart oder führe manuell aus: choco install python"
    } else {
        Write-Host "📦 Verwende Python unter: $pythonExe"

        # 9. requirements installieren
        $reqFile = Join-Path $outputFolder "requirements.txt"
        & "$pythonExe" -m pip install --upgrade pip
        & "$pythonExe" -m pip install -r "`"$reqFile`""

        # 10. app.py starten
        $appPath = Join-Path $outputFolder "app.py"
        Write-Host "`n▶️ Starte App..."
        Start-Process "$pythonExe" -ArgumentList "`"$appPath`""
    }

} catch {
    Write-Host "❌ FEHLER im Script: $_"
}

Stop-Transcript

Write-Host "`n✅ Setup abgeschlossen. Log-Datei: $log"
Read-Host -Prompt "Drücke Enter zum Beenden"
