# Eine vereinfachte Initialisierungsdatei für den Video Converter

# Temporären Ordner definieren
$tempFolder = Join-Path $env:TEMP "VideoConverter"
if (-not (Test-Path $tempFolder)) {
    New-Item -Path $tempFolder -ItemType Directory -Force | Out-Null
}

# Skripts herunterladen
$mainUrl = "https://raw.githubusercontent.com/jenssgb/Video-Converter/main/YouTubeConverter.ps1"
$mainScriptPath = Join-Path $tempFolder "YouTubeConverter.ps1"

Write-Host "Lade Skript herunter..."
Invoke-RestMethod -Uri $mainUrl -OutFile $mainScriptPath

# Skript ausführen
Write-Host "Starte Video Converter..."
& $mainScriptPath
    Write-Host "Fehler beim Starten des Video Converters: $_" -ForegroundColor Red
    Write-Host "Drücken Sie eine beliebige Taste, um fortzufahren..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
