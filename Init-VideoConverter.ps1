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

# Parameter-Block entfernen
$modifiedContent = $content -replace 'param\([^)]*\)', "# Parameter entfernt für die direkte Ausführung"

# Füge Null-Checks für $videoList.Items hinzu
$modifiedContent = $modifiedContent -replace '(\$videoList\.Items\[\$videoList\.Items\.Count - 1\] = .*?)(;|$)', 'if ($videoList -and $videoList.Items -and $videoList.Items.Count -gt 0) { $1 }$2'
$modifiedContent = $modifiedContent -replace '(\$videoList\.Items\.Add\(.*?\))(;|$)', 'if ($videoList -and $videoList.Items) { $1 }$2'
$modifiedContent = $modifiedContent -replace '(\$videoList\.Items\.Clear\(\))(;|$)', 'if ($videoList -and $videoList.Items) { $1 }$2'

# KEIN globales Ersetzen des SelectedIndex, da dies zu Syntaxfehlern führt
# Stattdessen nur bestimmte Zeilen finden und korrigieren

# Modifiziere GUI-Initialisierung
$guiInitCode = @"
# GUI-Elemente richtig initialisieren
try {
    # Prüfe auf null-Elemente
    if (-not `$videoList) { Write-Host "Warnung: VideoList ist nicht initialisiert" }
    
    # Stelle sicher, dass alle Event-Handler gebunden sind
    if (`$window -and `$videoList) {
        Write-Host "GUI-Elemente initialisiert"
    }
} catch {
    Write-Host "Fehler bei GUI-Initialisierung: `$_"
}

"@

# Füge den GUI-Initialisierungscode nach der Window-Erstellung ein
$modifiedContent = $modifiedContent -replace '(\$window = \[Windows\.Markup\.XamlReader\]::Load\(\$reader\))', "`$1`n$guiInitCode"

# Modifiziertes Skript speichern
$modifiedScriptPath = Join-Path $tempFolder "ModifiedYouTubeConverter.ps1"
Set-Content -Path $modifiedScriptPath -Value $modifiedContent

# Ausführung des modifizierten Skripts
Write-Host "Starte Video-Converter..."

# Direkte Ausführung des originalen Skripts, ohne Modifikationen
& $mainScriptPath
