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

# Modifiziere das Skript: Füge Null-Checks für $videoList hinzu
$modifiedContent = $content -replace '(\$videoList\.Items\[\$videoList\.Items\.Count - 1\] = ".*?")', 'if ($videoList -and $videoList.Items -and $videoList.Items.Count -gt 0) { $1 }'

# Füge weitere Null-Checks für alle ähnlichen Muster hinzu
$modifiedContent = $modifiedContent -replace '(\$videoList\.Items\.Add\(.*?\))', 'if ($videoList -and $videoList.Items) { $1 }'
$modifiedContent = $modifiedContent -replace '(\$videoList\.Items\.Clear\(\))', 'if ($videoList -and $videoList.Items) { $1 }'
$modifiedContent = $modifiedContent -replace '(\$videoList\.SelectedIndex = .*?)', 'if ($videoList) { $1 }'

# Entferne den Parameter-Block für die direkte Ausführung
$modifiedContent = $modifiedContent -replace 'param\([^)]*\)', "# Parameter entfernt für die direkte Ausführung"

# Modifiziere GUI-Initialisierung: Stell sicher, dass Elemente initialisiert werden
$guiInitCode = @"
# Sicherstelle, dass GUI-Elemente korrekt initialisiert sind
try {
    if (-not `$window) { Write-Host "Window wird initialisiert..." }
    if (-not `$videoList) { Write-Host "VideoList wird initialisiert..." }
    
    # Verzögerung für korrekte GUI-Initialisierung
    Start-Sleep -Milliseconds 500
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
& $modifiedScriptPath
