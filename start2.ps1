# ====================================================================================
# BluePolicy App-Installer für Windows – VERSION 1.2
# ====================================================================================

# 1. Adminrechte prüfen & ggf. Script mit Admin-Rechten neu starten
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "🛡️ Starte Script mit Adminrechten neu..."
    Start-Process powershell -Verb runAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

# 2. Logging starten
$log = "$env:TEMP\yt-setup-log.txt"
Start-Transcript -Path $log -Append

Write-Host ""
Write-Host "🌐 BluePolicy App Setup gestartet – VERSION 1.2"
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
    Write-Host "🔄 Pruefe/upgr. python, ffmpeg, vlc..."
    choco upgrade -y python ffmpeg vlc --install-if-not-installed

    # 5. Ausgabeordner auf Desktop anlegen
    $desktop      = [Environment]::GetFolderPath("Desktop")
    $outputFolder = Join-Path $desktop "YT-Downloads"
    if (!(Test-Path $outputFolder)) {
        New-Item -ItemType Directory -Path $outputFolder | Out-Null
        Write-Host "📁 Ordner erstellt: $outputFolder"
    }

    # 6. app.py & requirements.txt von GitHub laden
    $repoBase = "https://raw.githubusercontent.com/jenssgb/Video-Converter/main"
    $toFetch = @(
        @{ Name="app.py";           Url="$repoBase/app.py" },
        @{ Name="requirements.txt"; Url="$repoBase/requirements.txt" }
    )
    foreach ($f in $toFetch) {
        $path = Join-Path $outputFolder $f.Name
        Write-Host "🌐 Lade $($f.Name)..."
        Invoke-WebRequest -Uri $f.Url -OutFile $path -UseBasicParsing -ErrorAction Stop
    }

    # 7. VERSION-Datei optional lesen (404 abfangen)
    $versionUrl  = "$repoBase/VERSION"
    $versionFile = Join-Path $outputFolder "VERSION"
    try {
        Invoke-WebRequest -Uri $versionUrl -OutFile $versionFile -UseBasicParsing -ErrorAction Stop
        $ver = Get-Content $versionFile -First 1
        Write-Host "`n🆔 Aktuelle App-Version/Commit: $ver`n"
    } catch {
        Write-Host "`n⚠️ Keine VERSION-Datei gefunden – übersprungen.`n"
    }

    # 8. Python dynamisch finden
    $pythonExe = (& where.exe python 2>$null | Select-Object -First 1)
    if (-not $pythonExe -or -not (Test-Path $pythonExe)) {
        Write-Host "❌ Python nicht im PATH gefunden. Bitte choco install python ausführen."
        throw "Python.exe fehlt"
    }
    Write-Host "📦 Verwende Python: $pythonExe"

    # 9. requirements installieren
    $req = Join-Path $outputFolder "requirements.txt"
    Write-Host "📥 Installiere Abhängigkeiten..."
    & $pythonExe -m pip install --upgrade pip
    & $pythonExe -m pip install -r "`"$req`""

    # 10. App starten
    $app = Join-Path $outputFolder "app.py"
    Write-Host "`n▶️ Starte App..."
    Start-Process $pythonExe -ArgumentList "`"$app`""

} catch {
    Write-Host "❌ FEHLER: $($_.Exception.Message)"
}

Stop-Transcript

# 11. Fenster offen halten
Write-Host "`n✅ Setup abgeschlossen. Log-Datei: $log"
Read-Host -Prompt "Drücke Enter zum Beenden"
