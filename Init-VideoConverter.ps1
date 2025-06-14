# Init-VideoConverter.ps1 - Lädt alle benötigten Skripte herunter und startet den Konverter

$baseUrl = "https://raw.githubusercontent.com/jenssgb/Video-Converter/main"
$tempFolder = Join-Path $env:TEMP "VideoConverter"

# Temporären Ordner erstellen
if (-not (Test-Path $tempFolder)) {
    New-Item -Path $tempFolder -ItemType Directory -Force | Out-Null
}

# Liste der Dateien, die heruntergeladen werden müssen
$files = @(
    "YouTubeConverter.ps1",
    "RunspaceManager.ps1",
    "VideoProcessingHelper.ps1"
)

# Alle Dateien herunterladen
foreach ($file in $files) {
    $url = "$baseUrl/$file"
    $outputPath = Join-Path $tempFolder $file
    
    Write-Host "Lade herunter: $file..."
    Invoke-RestMethod -Uri $url -OutFile $outputPath
}

# Hilfsskripte als Module importieren
Write-Host "Importiere Hilfsskripte..."
. (Join-Path $tempFolder "RunspaceManager.ps1")
. (Join-Path $tempFolder "VideoProcessingHelper.ps1")

# Hauptskript ausführen - mit Invoke-Expression statt direktem Aufruf
Write-Host "Starte Video-Converter..."
$mainScriptPath = Join-Path $tempFolder "YouTubeConverter.ps1"
$mainScriptContent = Get-Content -Path $mainScriptPath -Raw

# Skript mit Invoke-Expression ausführen, um Parameter-Block-Problem zu umgehen
Invoke-Expression $mainScriptContent
