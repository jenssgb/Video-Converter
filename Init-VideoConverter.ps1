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

# Startercode erstellen - ein Wrapper, der das Hauptskript aufruft
$wrapperPath = Join-Path $tempFolder "Starter.ps1"
$wrapperCode = @"
# Wrapper-Skript für YouTubeConverter
`$mainScriptPath = "$tempFolder\YouTubeConverter.ps1"

# Hilfsskripte laden
. "$tempFolder\RunspaceManager.ps1"
. "$tempFolder\VideoProcessingHelper.ps1"

# Prüfen, ob alle Dateien existieren
if (-not (Test-Path `$mainScriptPath)) {
    Write-Error "Hauptskript nicht gefunden: `$mainScriptPath"
    exit 1
}

# Parameter-Block umgehen und Skript ausführen
`$scriptContent = Get-Content -Path `$mainScriptPath -Raw
`$scriptBlock = [ScriptBlock]::Create(`$scriptContent)

# Skript in einem neuen Geltungsbereich ausführen
`$global:errorActionPreference = 'Continue'
. `$scriptBlock
"@

Set-Content -Path $wrapperPath -Value $wrapperCode

Write-Host "Starte Video-Converter..."
& $wrapperPath
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
