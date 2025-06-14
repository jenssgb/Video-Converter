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

# Hilfsskripte laden
Write-Host "Importiere Hilfsskripte..."
. (Join-Path $tempFolder "RunspaceManager.ps1")
. (Join-Path $tempFolder "VideoProcessingHelper.ps1")

# Skript analysieren und vorbereiten
Write-Host "Bereite Hauptskript vor..."
$mainScriptPath = Join-Path $tempFolder "YouTubeConverter.ps1"
$content = Get-Content -Path $mainScriptPath -Raw

# Problematischen Zugriff auf $videoList.Items sichern
$modifiedContent = $content -replace '\$videoList\.Items\[\$videoList\.Items\.Count - 1\] = "(.*?)"', 'if ($videoList -and $videoList.Items) { $videoList.Items[$videoList.Items.Count - 1] = "$1" }'

# Weitere potenzielle Null-Referenzen absichern
$modifiedContent = $modifiedContent -replace 'param\([^)]*\)', "# Parameter entfernt für die direkte Ausführung"

# Modifiziertes Skript speichern
$modifiedScriptPath = Join-Path $tempFolder "ModifiedYouTubeConverter.ps1"
Set-Content -Path $modifiedScriptPath -Value $modifiedContent

# Ausführung mit einer Pause für bessere GUI-Initialisierung
Write-Host "Starte Video-Converter..."
& $modifiedScriptPath
