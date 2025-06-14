# Einfache Initialisierungsdatei ohne komplexe Strukturen

# Temporären Ordner erstellen
$tempFolder = Join-Path $env:TEMP "VideoConverter"
if (-not (Test-Path $tempFolder)) {
    New-Item -Path $tempFolder -ItemType Directory -Force | Out-Null
}

# Hauptskript herunterladen
$mainUrl = "https://raw.githubusercontent.com/jenssgb/Video-Converter/main/YouTubeConverter.ps1"
$mainScriptPath = Join-Path $tempFolder "YouTubeConverter.ps1"

Write-Host "Lade Skript herunter..."
Invoke-WebRequest -Uri $mainUrl -OutFile $mainScriptPath -UseBasicParsing

# Skript ausführen
Write-Host "Starte Video Converter..."
& $mainScriptPath
    Write-Host "Fehler beim Starten des Video Converters: $_" -ForegroundColor Red
    Write-Host "Drücken Sie eine beliebige Taste, um fortzufahren..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
