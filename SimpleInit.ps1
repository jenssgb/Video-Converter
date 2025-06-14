# Eine stark vereinfachte Initialisierungsdatei für den Video Converter

# Temporären Ordner definieren
$tempFolder = Join-Path $env:TEMP "VideoConverter"
if (-not (Test-Path $tempFolder)) {
    New-Item -Path $tempFolder -ItemType Directory -Force | Out-Null
}

# Skripts direkt herunterladen und ausführen
try {
    # Hauptskript herunterladen und ausführen
    $mainUrl = "https://raw.githubusercontent.com/jenssgb/Video-Converter/main/YouTubeConverter.ps1"
    Write-Host "Starte Video Converter..."
    
    # Direkte Ausführung
    Invoke-Expression (Invoke-RestMethod -Uri $mainUrl)
}
catch {
    Write-Host "Fehler beim Starten des Video Converters: $_" -ForegroundColor Red
    Write-Host "Drücken Sie eine beliebige Taste, um fortzufahren..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
