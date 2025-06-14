# VideoProcessingHelper.ps1 - Enthält Funktionen für asynchrone Videokonvertierung

# Vereinfachte yt-dlp Funktion für zuverlässigeren Download
function Start-AsyncYoutubeDownload {
    param (
        [string]$Url,
        [string]$OutputPath,
        [scriptblock]$OnCompleted,
        [scriptblock]$OnProgress
    )
    
    # Skriptblock für den Download im Runspace
    $downloadScript = {
        param (
            [string]$Url,
            [string]$OutputPath
        )
        
        # Notwendige Funktionen im Runspace verfügbar machen
        function Send-ProgressUpdate {
            param (
                [string]$Status,
                [int]$PercentComplete = -1,
                [string]$CurrentOperation = "",
                [switch]$Completed
            )
            
            $progressEvent = New-Event -SourceIdentifier "VideoProcessingProgress" -MessageData @{
                Status = $Status
                PercentComplete = $PercentComplete
                CurrentOperation = $CurrentOperation
                Completed = $Completed.IsPresent
                Timestamp = Get-Date
            }
        }
        
        try {
            # Temporäres Verzeichnis für den Download
            $tempDir = Join-Path $OutputPath "temp_download"
            if (-not (Test-Path $tempDir)) {
                New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
            }
            
            Send-ProgressUpdate -Status "Download wird vorbereitet..." -PercentComplete 0
            
            # yt-dlp ausführen - direkt und synchron mit Fortschrittsüberwachung
            $ytDlpPath = "yt-dlp.exe" # Verwende globalen Pfad oder spezifiziere vollständig
            $outputTemplate = Join-Path $tempDir "video.%(ext)s"
            
            # Direkte, einfache Ausführung
            Send-ProgressUpdate -Status "Download startet..." -PercentComplete 5
            
            # Timeout setzen (10 Minuten)
            $timeoutSeconds = 600
            $timeout = New-TimeSpan -Seconds $timeoutSeconds
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            
            # Start den Prozess mit Umleitung der Ausgabe zur live Überwachung
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = $ytDlpPath
            $psi.Arguments = "--newline -f bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best --merge-output-format mp4 -o `"$outputTemplate`" `"$Url`""
            $psi.UseShellExecute = $false
            $psi.RedirectStandardOutput = $true
            $psi.RedirectStandardError = $true
            $psi.CreateNoWindow = $true
            
            $process = New-Object System.Diagnostics.Process
            $process.StartInfo = $psi
            
            # Event-Handler für Ausgabezeilen
            $outputSb = New-Object System.Text.StringBuilder
            $errorSb = New-Object System.Text.StringBuilder
            
            $outputHandler = {
                if (-not [String]::IsNullOrEmpty($EventArgs.Data)) {
                    $line = $EventArgs.Data
                    [void]$outputSb.AppendLine($line)
                    
                    # Fortschritt extrahieren und senden
                    if ($line -match '\[download\]\s+(\d+\.?\d*)%') {
                        $percentComplete = [math]::Floor([double]::Parse($matches[1], [System.Globalization.CultureInfo]::InvariantCulture))
                        Send-ProgressUpdate -Status "Video wird heruntergeladen..." -PercentComplete $percentComplete -CurrentOperation "Download läuft"
                    }
                }
            }
            
            $errorHandler = {
                if (-not [String]::IsNullOrEmpty($EventArgs.Data)) {
                    [void]$errorSb.AppendLine($EventArgs.Data)
                }
            }
            
            # Events registrieren
            $outEvent = Register-ObjectEvent -InputObject $process -EventName "OutputDataReceived" -Action $outputHandler
            $errEvent = Register-ObjectEvent -InputObject $process -EventName "ErrorDataReceived" -Action $errorHandler
            
            # Prozess starten und Output/Error asynchron lesen
            [void]$process.Start()
            $process.BeginOutputReadLine()
            $process.BeginErrorReadLine()
            
            # Warten auf Prozessende mit Timeout
            while (-not $process.HasExited) {
                Start-Sleep -Milliseconds 500
                if ($sw.Elapsed -gt $timeout) {
                    # Timeout erreicht
                    Send-ProgressUpdate -Status "Timeout beim Download" -PercentComplete 100 -Completed
                    $process.Kill()
                    throw "Der Download hat das Timeout von $timeoutSeconds Sekunden überschritten."
                }
            }
            
            # Events unregistrieren
            Unregister-Event -SourceIdentifier $outEvent.Name
            Unregister-Event -SourceIdentifier $errEvent.Name
            
            # Prüfen, ob der Prozess erfolgreich war
            if ($process.ExitCode -ne 0) {
                throw "yt-dlp ist mit Exit-Code $($process.ExitCode) fehlgeschlagen: $($errorSb.ToString())"
            }
            
            # Download abgeschlossen, Dateien finden
            Send-ProgressUpdate -Status "Download abgeschlossen, verschiebe Dateien..." -PercentComplete 95
            $downloadedFiles = Get-ChildItem -Path $tempDir -Filter "*.mp4"
            
            if ($downloadedFiles.Count -eq 0) {
                throw "Keine heruntergeladenen MP4-Dateien gefunden!"
            }
            
            # Datei in das Ausgabeverzeichnis verschieben
            $finalOutputPath = Join-Path $OutputPath $downloadedFiles[0].Name
            Move-Item -Path $downloadedFiles[0].FullName -Destination $finalOutputPath -Force
            
            # Verzeichnis aufräumen
            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
            
            Send-ProgressUpdate -Status "Download erfolgreich abgeschlossen" -PercentComplete 100 -Completed
            
            # Pfad der heruntergeladenen Datei zurückgeben
            return $finalOutputPath
        }
        catch {
            Send-ProgressUpdate -Status "Fehler beim Download: $_" -PercentComplete 100 -Completed
            return $null
        }
    }
    
    # Runspace für den Download erstellen und starten
    $runspaceInfo = New-ProcessingRunspace -ScriptBlock $downloadScript -Parameters @{
        Url = $Url
        OutputPath = $OutputPath
    } -OnCompleted $OnCompleted
    
    # Event-Handler für Fortschrittsupdates registrieren
    if ($OnProgress) {
        Register-EngineEvent -SourceIdentifier "VideoProcessingProgress" -Action $OnProgress
    }
    
    return $runspaceInfo
}

# Haupt-Videoverarbeitungsfunktion
function Start-AsyncVideoProcessing {
    param (
        [string]$InputVideoPath,
        [string]$OutputPath,
        [string]$Format = "mp4",
        [scriptblock]$OnCompleted,
        [scriptblock]$OnProgress
    )
    
    # Zuerst prüfen, ob es sich um eine URL handelt
    $isUrl = $InputVideoPath -match '^https?://'
    
    if ($isUrl) {
        # Bei einer URL zuerst asynchron herunterladen
        $downloadCompletedScript = {
            param($Results, $Success, $ErrorInfo, $Cancelled)
            
            if ($Success -and $Results) {
                # Nach erfolgreichem Download die Konvertierung starten
                $videoPath = $Results
                Start-AsyncVideoConversion -InputVideoPath $videoPath -OutputPath $OutputPath -Format $Format -OnCompleted $OnCompleted -OnProgress $OnProgress
            }
            else {
                # Bei Fehlern den Fehler melden
                if ($OnCompleted) {
                    & $OnCompleted -Results $null -Success $false -ErrorInfo $ErrorInfo -Cancelled $Cancelled
                }
            }
        }
        
        # Download starten
        return Start-AsyncYoutubeDownload -Url $InputVideoPath -OutputPath $OutputPath -OnCompleted $downloadCompletedScript -OnProgress $OnProgress
    }
    else {
        # Bei lokaler Datei direkt die Konvertierung starten
        return Start-AsyncVideoConversion -InputVideoPath $InputVideoPath -OutputPath $OutputPath -Format $Format -OnCompleted $OnCompleted -OnProgress $OnProgress
    }
}

# Funktion für die asynchrone Video-Konvertierung
function Start-AsyncVideoConversion {
    param (
        [string]$InputVideoPath,
        [string]$OutputPath,
        [string]$Format = "mp4",
        [scriptblock]$OnCompleted,
        [scriptblock]$OnProgress
    )
    
    # Skriptblock für die Konvertierung im Runspace
    $conversionScript = {
        param (
            [string]$InputVideoPath,
            [string]$OutputPath,
            [string]$Format
        )
        
        # Notwendige Funktionen im Runspace verfügbar machen
        function Send-ProgressUpdate {
            param (
                [string]$Status,
                [int]$PercentComplete = -1,
                [string]$CurrentOperation = "",
                [switch]$Completed
            )
            
            $progressEvent = New-Event -SourceIdentifier "VideoProcessingProgress" -MessageData @{
                Status = $Status
                PercentComplete = $PercentComplete
                CurrentOperation = $CurrentOperation
                Completed = $Completed.IsPresent
                Timestamp = Get-Date
            }
        }
        
        try {
            # FFmpeg-Pfad
            $ffmpegPath = Join-Path $PSScriptRoot "tools\ffmpeg.exe"
            
            # Ausgabedateiname
            $inputFileName = [System.IO.Path]::GetFileNameWithoutExtension($InputVideoPath)
            $outputFilePath = Join-Path $OutputPath "$inputFileName.$Format"
            
            Send-ProgressUpdate -Status "Konvertierung wird vorbereitet..." -PercentComplete 0
            
            # FFmpeg-Prozess starten
            $process = Start-Process -FilePath $ffmpegPath -ArgumentList "-i", "`"$InputVideoPath`"", "-c:v", "libx264", "-c:a", "aac", "-y", "`"$outputFilePath`"" -NoNewWindow -PassThru -RedirectStandardError "$OutputPath\ffmpeg_log.txt"
            
            # Warten auf Abschluss mit periodischem Log-Check für Fortschritt
            while (!$process.HasExited) {
                Start-Sleep -Seconds 1
                
                # Log-Datei für Fortschritt überprüfen
                if (Test-Path "$OutputPath\ffmpeg_log.txt") {
                    $logContent = Get-Content "$OutputPath\ffmpeg_log.txt" -Tail 10
                    $durationLine = $logContent | Where-Object { $_ -match 'Duration: (\d+):(\d+):(\d+)' } | Select-Object -First 1
                    $timeLine = $logContent | Where-Object { $_ -match 'time=(\d+):(\d+):(\d+)' } | Select-Object -Last 1
                    
                    if ($durationLine -and $timeLine) {
                        # Dauer extrahieren
                        $durationMatch = $durationLine | Select-String -Pattern 'Duration: (\d+):(\d+):(\d+)'
                        $hours = [int]$durationMatch.Matches.Groups[1].Value
                        $minutes = [int]$durationMatch.Matches.Groups[2].Value
                        $seconds = [int]$durationMatch.Matches.Groups[3].Value
                        $totalDurationSeconds = $hours * 3600 + $minutes * 60 + $seconds
                        
                        # Aktuelle Zeit extrahieren
                        $timeMatch = $timeLine | Select-String -Pattern 'time=(\d+):(\d+):(\d+)'
                        $currentHours = [int]$timeMatch.Matches.Groups[1].Value
                        $currentMinutes = [int]$timeMatch.Matches.Groups[2].Value
                        $currentSeconds = [int]$timeMatch.Matches.Groups[3].Value
                        $currentTimeSeconds = $currentHours * 3600 + $currentMinutes * 60 + $currentSeconds
                        
                        # Fortschritt berechnen
                        if ($totalDurationSeconds -gt 0) {
                            $percentComplete = [math]::Min(95, [math]::Floor(($currentTimeSeconds / $totalDurationSeconds) * 100))
                            Send-ProgressUpdate -Status "Video wird konvertiert..." -PercentComplete $percentComplete -CurrentOperation "Konvertiere zu $Format"
                        }
                    }
                }
            }
            
            # Aufräumen
            if (Test-Path "$OutputPath\ffmpeg_log.txt") {
                Remove-Item "$OutputPath\ffmpeg_log.txt" -Force
            }
            
            # Erfolgsabschluss
            if (Test-Path $outputFilePath) {
                Send-ProgressUpdate -Status "Konvertierung erfolgreich abgeschlossen" -PercentComplete 100 -Completed
                return $outputFilePath
            }
            else {
                throw "Die Ausgabedatei wurde nicht erstellt."
            }
        }
        catch {
            Send-ProgressUpdate -Status "Fehler bei der Konvertierung: $_" -PercentComplete 100 -Completed
            return $null
        }
    }
    
    # Runspace für die Konvertierung erstellen und starten
    $runspaceInfo = New-ProcessingRunspace -ScriptBlock $conversionScript -Parameters @{
        InputVideoPath = $InputVideoPath
        OutputPath = $OutputPath
        Format = $Format
    } -OnCompleted $OnCompleted
    
    # Event-Handler für Fortschrittsupdates registrieren
    if ($OnProgress) {
        Register-EngineEvent -SourceIdentifier "VideoProcessingProgress" -Action $OnProgress
    }
    
    return $runspaceInfo
}
