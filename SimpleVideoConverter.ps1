#
# SimpleVideoConverter.ps1 - Ein einfaches Skript für YouTube-Video-Download und Konvertierung
#

# 1. Konstanten und Konfiguration
$version = "1.0.0"
$defaultOutputFolder = Join-Path $env:USERPROFILE "Videos\Konvertiert"

# Zeige Informationen und Optionen an
function Show-Info {
    Clear-Host
    Write-Host "==== Simple Video Converter v$version ====" -ForegroundColor Cyan
    Write-Host "1. Abhängigkeiten prüfen und installieren"
    Write-Host "2. YouTube-Video herunterladen und konvertieren"
    Write-Host "3. Ausgabeordner öffnen"
    Write-Host "4. Beenden"
    Write-Host "=======================================" -ForegroundColor Cyan
}

# 2. Abhängigkeiten prüfen und installieren
function Install-Dependencies {
    Write-Host "`nPrüfe Abhängigkeiten..." -ForegroundColor Yellow
    
    # Prüfen, ob Chocolatey installiert ist
    $chocoInstalled = $false
    try {
        $chocoVersion = choco -v
        $chocoInstalled = $true
        Write-Host "Chocolatey ist installiert (Version: $chocoVersion)" -ForegroundColor Green
    }
    catch {
        Write-Host "Chocolatey ist nicht installiert. Installation wird gestartet..." -ForegroundColor Yellow
        try {
            # Chocolatey installieren
            Set-ExecutionPolicy Bypass -Scope Process -Force
            Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
            $chocoInstalled = $true
            Write-Host "Chocolatey wurde erfolgreich installiert." -ForegroundColor Green
        }
        catch {
            Write-Host "Fehler bei der Installation von Chocolatey: $_" -ForegroundColor Red
            return $false
        }
    }
    
    if ($chocoInstalled) {
        # yt-dlp installieren oder aktualisieren
        Write-Host "Installiere/aktualisiere yt-dlp..." -ForegroundColor Yellow
        choco install yt-dlp -y
        
        # ffmpeg installieren oder aktualisieren
        Write-Host "Installiere/aktualisiere ffmpeg..." -ForegroundColor Yellow
        choco install ffmpeg -y
        
        # Prüfen, ob die Programme verfügbar sind
        $ytdlpPath = Get-Command yt-dlp -ErrorAction SilentlyContinue
        $ffmpegPath = Get-Command ffmpeg -ErrorAction SilentlyContinue
        
        if ($ytdlpPath -and $ffmpegPath) {
            Write-Host "`nAlle Abhängigkeiten sind installiert und aktualisiert:" -ForegroundColor Green
            Write-Host "- yt-dlp: $($ytdlpPath.Source)"
            Write-Host "- ffmpeg: $($ffmpegPath.Source)"
            
            # Neustarten der PATH-Variable
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            
            return $true
        }
        else {
            Write-Host "`nFehler: Nicht alle Abhängigkeiten konnten installiert werden." -ForegroundColor Red
            if (-not $ytdlpPath) { Write-Host "- yt-dlp wurde nicht gefunden" -ForegroundColor Red }
            if (-not $ffmpegPath) { Write-Host "- ffmpeg wurde nicht gefunden" -ForegroundColor Red }
            return $false
        }
    }
    
    return $false
}

# 3. Video herunterladen und konvertieren
function Start-VideoProcessing {
    param (
        [string]$VideoUrl,
        [string]$OutputFolder = $defaultOutputFolder
    )
    
    if ([string]::IsNullOrWhiteSpace($VideoUrl)) {
        Write-Host "`nBitte geben Sie eine gültige YouTube-URL ein:" -ForegroundColor Yellow
        $VideoUrl = Read-Host
        
        if ([string]::IsNullOrWhiteSpace($VideoUrl)) {
            Write-Host "Keine URL eingegeben. Vorgang abgebrochen." -ForegroundColor Red
            return
        }
    }
    
    # Ausgabeordner erstellen, falls nicht vorhanden
    if (-not (Test-Path $OutputFolder)) {
        try {
            New-Item -Path $OutputFolder -ItemType Directory -Force | Out-Null
            Write-Host "`nAusgabeordner erstellt: $OutputFolder" -ForegroundColor Green
        }
        catch {
            Write-Host "`nFehler beim Erstellen des Ausgabeordners: $_" -ForegroundColor Red
            return
        }
    }
    
    # Temporären Arbeitsordner erstellen
    $tempWorkingDir = Join-Path $env:TEMP "VideoConverter_$(Get-Random)"
    New-Item -Path $tempWorkingDir -ItemType Directory -Force | Out-Null
    
    try {
        # 1. Video herunterladen
        Write-Host "`nStarte Download von: $VideoUrl" -ForegroundColor Yellow
        $downloadProcess = Start-Process -FilePath "yt-dlp" -ArgumentList "--newline", "--no-warnings", "-f", "bestvideo[height<=1080]+bestaudio/best[height<=1080]/best", "--merge-output-format", "mp4", "-o", "`"$tempWorkingDir\%(title)s.%(ext)s`"", "`"$VideoUrl`"" -NoNewWindow -PassThru -Wait
        
        if ($downloadProcess.ExitCode -ne 0) {
            Write-Host "Fehler beim Herunterladen des Videos (Exit-Code: $($downloadProcess.ExitCode))" -ForegroundColor Red
            return
        }
        
        # Heruntergeladene Datei finden
        $downloadedFiles = Get-ChildItem -Path $tempWorkingDir -Filter "*.mp4"
        
        if ($downloadedFiles.Count -eq 0) {
            Write-Host "Keine MP4-Datei gefunden nach dem Download." -ForegroundColor Red
            return
        }
        
        $videoFile = $downloadedFiles[0]
        Write-Host "Video erfolgreich heruntergeladen: $($videoFile.Name)" -ForegroundColor Green
        
        # 2. Video konvertieren (falls gewünscht, hier überspringen wir diesen Schritt und verschieben direkt)
        $finalPath = Join-Path $OutputFolder $videoFile.Name
        
        # Datei ins Zielverzeichnis verschieben
        Move-Item -Path $videoFile.FullName -Destination $finalPath -Force
        
        Write-Host "`nVideo wurde erfolgreich verarbeitet und gespeichert unter:" -ForegroundColor Green
        Write-Host $finalPath -ForegroundColor Cyan
        
        # Frage, ob der Ausgabeordner geöffnet werden soll
        Write-Host "`nMöchten Sie den Ausgabeordner öffnen? (J/N)" -ForegroundColor Yellow
        $openFolder = Read-Host
        
        if ($openFolder -eq "J" -or $openFolder -eq "j") {
            Start-Process "explorer.exe" -ArgumentList $OutputFolder
        }
    }
    catch {
        Write-Host "`nFehler bei der Videoverarbeitung: $_" -ForegroundColor Red
    }
    finally {
        # Aufräumen
        if (Test-Path $tempWorkingDir) {
            Remove-Item -Path $tempWorkingDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# 4. Ausgabeordner öffnen
function Open-OutputFolder {
    if (Test-Path $defaultOutputFolder) {
        Start-Process "explorer.exe" -ArgumentList $defaultOutputFolder
    }
    else {
        Write-Host "`nAusgabeordner existiert nicht. Soll er erstellt werden? (J/N)" -ForegroundColor Yellow
        $createFolder = Read-Host
        
        if ($createFolder -eq "J" -or $createFolder -eq "j") {
            New-Item -Path $defaultOutputFolder -ItemType Directory -Force | Out-Null
            Start-Process "explorer.exe" -ArgumentList $defaultOutputFolder
        }
    }
}

# 5. Hauptmenü
function Show-MainMenu {
    $continue = $true
    
    while ($continue) {
        Show-Info
        
        $choice = Read-Host "`nAuswahl"
        
        switch ($choice) {
            "1" {
                $result = Install-Dependencies
                if ($result) {
                    Write-Host "`nAlle Abhängigkeiten sind bereit." -ForegroundColor Green
                }
                else {
                    Write-Host "`nEinige Abhängigkeiten konnten nicht installiert werden." -ForegroundColor Red
                }
                Write-Host "`nDrücken Sie eine beliebige Taste, um fortzufahren..."
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            "2" {
                Write-Host "`nBitte geben Sie eine YouTube-URL ein:"
                $url = Read-Host
                Start-VideoProcessing -VideoUrl $url
                Write-Host "`nDrücken Sie eine beliebige Taste, um fortzufahren..."
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            "3" {
                Open-OutputFolder
            }
            "4" {
                $continue = $false
            }
            default {
                Write-Host "`nUngültige Auswahl. Bitte versuchen Sie es erneut." -ForegroundColor Red
                Start-Sleep -Seconds 2
            }
        }
    }
}

# 6. Skript starten
Clear-Host
Write-Host "Willkommen beim Simple Video Converter!" -ForegroundColor Green
Show-MainMenu
