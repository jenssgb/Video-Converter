<#
.SYNOPSIS
  YouTubeConverter GUI (Win10/11): Benutzerfreundliche grafische Oberfläche zum Herunterladen und Konvertieren von YouTube-Videos

.DESCRIPTION
  • Moderne grafische Benutzeroberfläche
  • Einfache URL-Eingabe
  • Visueller Fortschritt und Status
  • Liste aller verarbeiteten Videos
  • Automatische Installation der benötigten Tools
  • Keine Kommandozeilen-Kenntnisse erforderlich
#>
param(
    [switch]$GUI  # GUI-Modus aktivieren
)

# Standardmäßig GUI-Modus aktivieren
if (-not $PSBoundParameters.ContainsKey('GUI')) {
    $GUI = $true
}

# Windows Forms laden
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Globale Variablen
$script:isProcessing = $false
$script:videoQueue = @()
$script:processedVideos = @()

# --- 1) Admin Self-Elevation ---
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
     ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process pwsh "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# --- 2) Chocolatey Bootstrap & Pfad ---
$chocoRoot = Join-Path $env:ProgramData 'chocolatey'
$chocoExe  = Join-Path $chocoRoot 'bin\choco.exe'
if (-not (Test-Path $chocoExe)) {
    Write-Host "Chocolatey wird installiert..." -ForegroundColor Cyan
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-Expression ((New-Object Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
}
# Session-PATH aktualisieren
$env:Path += ";$chocoRoot\bin"

# --- 3) Setup Desktop-Ordner ---
$desktop = [Environment]::GetFolderPath('Desktop')
$baseDir = Join-Path $desktop 'YouTubeConverter'
if (!(Test-Path $baseDir)) { New-Item -ItemType Directory -Path $baseDir | Out-Null }
Set-Location $baseDir

# --- 4) Install/Update Dependencies ---
Write-Host "Installiere/aktualisiere yt-dlp & ffmpeg..." -ForegroundColor Cyan
& $chocoExe install yt-dlp ffmpeg -y > $null 2>&1
& $chocoExe upgrade yt-dlp ffmpeg -y  > $null 2>&1

# --- 5) Video-Verarbeitungs-Funktion ---
function Start-VideoProcessing {
    param([string]$url, [System.Windows.Forms.ProgressBar]$progressBar, [System.Windows.Forms.Label]$statusLabel, [System.Windows.Forms.ListBox]$videoList)
    
    if ($script:isProcessing) {
        [System.Windows.Forms.MessageBox]::Show("Es wird bereits ein Video verarbeitet. Bitte warten Sie.", "Hinweis", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        return
    }
      $script:isProcessing = $true
    $statusLabel.Text = "Starte Download..."
    $progressBar.Value = 0
    
    # Prüfe ob Tools verfügbar sind
    try {
        $ytdlpTest = Get-Command "yt-dlp.exe" -ErrorAction Stop
        Write-Host "Debug: yt-dlp gefunden: $($ytdlpTest.Source)" -ForegroundColor Green
    } catch {
        throw "yt-dlp.exe nicht gefunden. Bitte starten Sie das Skript als Administrator neu."
    }
    
    try {
        $ffmpegTest = Get-Command "ffmpeg.exe" -ErrorAction Stop
        Write-Host "Debug: ffmpeg gefunden: $($ffmpegTest.Source)" -ForegroundColor Green
    } catch {
        throw "ffmpeg.exe nicht gefunden. Bitte starten Sie das Skript als Administrator neu."
    }
      try {
        # Video-Info zur Liste hinzufügen
        $videoItem = "$url - Download läuft..."
        $videoList.Items.Add($videoItem)
        $videoList.SelectedIndex = $videoList.Items.Count - 1
        
        # Verfügbare Formate anzeigen für Debug-Zwecke
        Write-Host "Debug: Prüfe verfügbare Formate..." -ForegroundColor Yellow
        $formatCheck = Start-Process -FilePath "yt-dlp.exe" -ArgumentList "--list-formats", $url -PassThru -NoNewWindow -RedirectStandardOutput "formats.log" -RedirectStandardError "format_errors.log" -WorkingDirectory $baseDir
        $formatCheck.WaitForExit()
        
        if (Test-Path "formats.log") {
            $formats = Get-Content "formats.log" -Raw
            Write-Host "Debug: Verfügbare Formate:`n$formats" -ForegroundColor Cyan
        }
        
        # Download mit simuliertem Fortschritt
        $statusLabel.Text = "Lade Video herunter..."
        for ($i = 0; $i -le 50; $i += 10) {
            $progressBar.Value = $i
            Start-Sleep -Milliseconds 200
        }# Echter Download mit hoher Qualität (1080p bevorzugt)
        $downloadArgs = @(
            "--newline",
            "--no-warnings",
            "-f", "bestvideo[height<=1080]+bestaudio[acodec!=none]/best[height<=1080]/bestvideo+bestaudio/best",
            "--merge-output-format", "mp4",
            "--ignore-errors",
            "-o", "%(title)s.%(ext)s",
            $url
        )
        $statusLabel.Text = "Starte yt-dlp Download (1080p bevorzugt)..."
        
        Write-Host "Debug: Starte yt-dlp mit hoher Qualität (bis 1080p)" -ForegroundColor Yellow
        Write-Host "Debug: Argumente: $($downloadArgs -join ' ')" -ForegroundColor Cyan
        
        $processInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processInfo.FileName = "yt-dlp.exe"
        $processInfo.Arguments = $downloadArgs -join " "
        $processInfo.UseShellExecute = $false
        $processInfo.RedirectStandardOutput = $true
        $processInfo.RedirectStandardError = $true
        $processInfo.CreateNoWindow = $true
        $processInfo.WorkingDirectory = $baseDir
        
        $process = [System.Diagnostics.Process]::Start($processInfo)
        
        $output = ""
        $errorOutput = ""
        
        # Output lesen
        $outputReader = $process.StandardOutput
        $errorReader = $process.StandardError
        
        while (-not $process.HasExited) {
            Start-Sleep -Milliseconds 500
            $progressBar.Value = [Math]::Min(50, $progressBar.Value + 1)
            
            # Output lesen wenn verfügbar
            if (-not $outputReader.EndOfStream) {
                $line = $outputReader.ReadLine()
                $output += $line + "`n"
                Write-Host "yt-dlp: $line" -ForegroundColor Cyan
            }
              # Error lesen wenn verfügbar
            if (-not $errorReader.EndOfStream) {
                $errorLine = $errorReader.ReadLine()
                $errorOutput += $errorLine + "`n"
                
                # Spezielle Behandlung für bekannte YouTube-Warnungen
                if ($errorLine -match "Some tv client.*DRM protected" -or $errorLine -match "Some web client.*missing a url") {
                    Write-Host "YouTube-Warnung (normal): $errorLine" -ForegroundColor Yellow
                } elseif ($errorLine -match "WARNING:") {
                    Write-Host "Warnung: $errorLine" -ForegroundColor Yellow
                } else {
                    Write-Host "yt-dlp Error: $errorLine" -ForegroundColor Red
                }
            }
        }
        
        # Restliche Output lesen
        $output += $outputReader.ReadToEnd()
        $errorOutput += $errorReader.ReadToEnd()
          Write-Host "Debug: yt-dlp Exit Code: $($process.ExitCode)" -ForegroundColor Yellow
        Write-Host "Debug: yt-dlp Output: $output" -ForegroundColor Green
        if ($errorOutput) {
            Write-Host "Debug: yt-dlp Errors/Warnings: $errorOutput" -ForegroundColor Yellow
        }
        
        # Prüfe sowohl Exit-Code als auch ob Dateien heruntergeladen wurden
        $downloadedFiles = Get-ChildItem -File -Path $baseDir | Where-Object { $_.CreationTime -gt (Get-Date).AddMinutes(-2) }        
        if ($process.ExitCode -eq 0 -and $downloadedFiles.Count -gt 0) {
            $progressBar.Value = 60
            $statusLabel.Text = "Download abgeschlossen, starte Konvertierung..."
            Write-Host "Debug: Download erfolgreich - $($downloadedFiles.Count) Datei(en) heruntergeladen" -ForegroundColor Green
            
            # Neueste Datei finden
            $latest = Get-ChildItem -File | Sort-Object CreationTime -Descending | Select-Object -First 1
            if ($latest) {
                Write-Host "Debug: Gefundene Datei zum Konvertieren: $($latest.FullName)" -ForegroundColor Green
                
                # Transcoding mit exakt den gleichen Parametern wie VLC
                $statusLabel.Text = "Konvertiere Video..."
                $outputFile = "_VLC_Edit_$($latest.BaseName).mp4"  # Gleicher Dateiname wie VLC
                
                Write-Host "Debug: Starte FFmpeg Konvertierung zu: $outputFile (VLC-kompatible Parameter)" -ForegroundColor Yellow
                
                # VLC Parameter-Übersetzung zu FFmpeg:
                # vcodec="fmp4" -> -c:v libx264 -profile:v main (fmp4 ist ein H.264 Profile)
                # vb="1800" -> -b:v 1800k
                # fps="24" -> -r 24 (Output-Framerate)
                # scale="0.5" -> -vf "scale=iw*0.5:ih*0.5"
                # acodec="mp2a" -> -c:a mp2 (MP2 Audio)
                # ab="320" -> -b:a 320k
                # channels=2 -> -ac 2
                # samplerate="48000" -> -ar 48000
                
                $ffmpegArgs = @(
                    "-i", $latest.FullName,
                    "-c:v", "libx264",
                    "-profile:v", "main",           # Entspricht VLC's fmp4
                    "-b:v", "1800k",                # Bitrate Video
                    "-r", "24",                     # Output-Framerate (wie VLC fps)
                    "-vf", "scale=iw*0.5:ih*0.5",  # Skalierung auf 50%
                    "-c:a", "mp2",                  # MP2 Audio-Codec
                    "-b:a", "320k",                 # Audio-Bitrate
                    "-ac", "2",                     # 2 Audio-Kanäle
                    "-ar", "48000",                 # Sample-Rate
                    "-f", "mp4",                    # MP4 Container-Format
                    "-y",                           # Überschreiben ohne Nachfrage
                    $outputFile
                )                
                Write-Host "Debug: VLC-zu-FFmpeg Parameter-Übersetzung:" -ForegroundColor Cyan
                Write-Host "  VLC: vcodec=fmp4, vb=1800, fps=24, scale=0.5" -ForegroundColor Cyan
                Write-Host "  FFmpeg: -c:v libx264 -profile:v main -b:v 1800k -r 24 -vf scale=iw*0.5:ih*0.5" -ForegroundColor Cyan
                Write-Host "  VLC: acodec=mp2a, ab=320, channels=2, samplerate=48000" -ForegroundColor Cyan
                Write-Host "  FFmpeg: -c:a mp2 -b:a 320k -ac 2 -ar 48000" -ForegroundColor Cyan
                
                Write-Host "Debug: Input-Datei: '$($latest.FullName)'" -ForegroundColor Yellow
                Write-Host "Debug: Output-Datei: '$outputFile'" -ForegroundColor Yellow
                
                # FFmpeg mit korrekter Argument-Behandlung für Dateien mit Leerzeichen
                $ffmpegProcess = Start-Process -FilePath "ffmpeg.exe" -ArgumentList $ffmpegArgs -PassThru -NoNewWindow -RedirectStandardOutput "ffmpeg_output.log" -RedirectStandardError "ffmpeg_error.log" -WorkingDirectory $baseDir
                
                $ffmpegOutput = ""
                $ffmpegError = ""
                
                while (-not $ffmpegProcess.HasExited) {
                    Start-Sleep -Milliseconds 500
                    $progressBar.Value = [Math]::Min(100, $progressBar.Value + 2)
                }
                
                # Log-Dateien lesen
                if (Test-Path "ffmpeg_output.log") {
                    $ffmpegOutput = Get-Content "ffmpeg_output.log" -Raw
                    Write-Host "FFmpeg Output: $ffmpegOutput" -ForegroundColor Cyan
                }
                
                if (Test-Path "ffmpeg_error.log") {
                    $ffmpegError = Get-Content "ffmpeg_error.log" -Raw
                    Write-Host "FFmpeg Error: $ffmpegError" -ForegroundColor Red
                }
                
                Write-Host "Debug: FFmpeg Exit Code: $($ffmpegProcess.ExitCode)" -ForegroundColor Yellow
                  if ($ffmpegProcess.ExitCode -eq 0) {
                    $progressBar.Value = 100
                    $statusLabel.Text = "Erfolgreich abgeschlossen!"
                    Write-Host "Debug: Konvertierung erfolgreich abgeschlossen" -ForegroundColor Green
                    
                    # Status in der Liste aktualisieren
                    $videoList.Items[$videoList.Items.Count - 1] = "$url - ✅ FERTIG"
                    $script:processedVideos += @{URL = $url; Status = "Erfolgreich"; File = $outputFile}
                    
                    [System.Windows.Forms.MessageBox]::Show("Video erfolgreich heruntergeladen und konvertiert!`nDatei: $outputFile", "Erfolg", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)                } else {
                    $errorMsg = "Konvertierung fehlgeschlagen (Exit Code: $($ffmpegProcess.ExitCode))"
                    if ($ffmpegError) {
                        $errorMsg += "`nFFmpeg Fehler: $ffmpegError"
                    }
                    Write-Host "Debug: $errorMsg" -ForegroundColor Red                    throw $errorMsg
                }
            } else {
                throw "Keine heruntergeladene Datei gefunden"
            }
        } elseif ($process.ExitCode -eq 0 -and $downloadedFiles.Count -eq 0) {
            throw "yt-dlp beendet ohne Fehler, aber keine Dateien wurden heruntergeladen. Möglicherweise ist das Video nicht verfügbar oder DRM-geschützt."
        } else {
            # Bei Fehlern versuche alternative Download-Strategie
            Write-Host "Debug: Erster Download-Versuch fehlgeschlagen, versuche Fallback-Strategie..." -ForegroundColor Yellow
              # Fallback mit besserer Qualität (720p als Minimum)
            $fallbackArgs = @(
                "--newline",
                "--no-warnings", 
                "-f", "best[height>=720]/bestvideo[height>=720]+bestaudio/best[height>=480]/best",
                "--merge-output-format", "mp4",
                "-o", "%(title)s_fallback.%(ext)s",
                $url
            )
            
            $statusLabel.Text = "Versuche alternative Download-Methode (720p bevorzugt)..."
            Write-Host "Debug: Fallback mit höherer Qualität (720p minimum)" -ForegroundColor Yellow
            
            $fallbackInfo = New-Object System.Diagnostics.ProcessStartInfo
            $fallbackInfo.FileName = "yt-dlp.exe"
            $fallbackInfo.Arguments = $fallbackArgs -join " "
            $fallbackInfo.UseShellExecute = $false
            $fallbackInfo.RedirectStandardOutput = $true
            $fallbackInfo.RedirectStandardError = $true
            $fallbackInfo.CreateNoWindow = $true
            $fallbackInfo.WorkingDirectory = $baseDir
            
            $fallbackProcess = [System.Diagnostics.Process]::Start($fallbackInfo)
            $fallbackProcess.WaitForExit()
            
            $fallbackFiles = Get-ChildItem -File -Path $baseDir | Where-Object { $_.CreationTime -gt (Get-Date).AddMinutes(-2) }
            
            if ($fallbackProcess.ExitCode -eq 0 -and $fallbackFiles.Count -gt 0) {
                Write-Host "Debug: Fallback-Download erfolgreich!" -ForegroundColor Green
                $progressBar.Value = 60
                $statusLabel.Text = "Alternative Download-Methode erfolgreich, starte Konvertierung..."
            } else {
                $errorMsg = "Alle Download-Versuche fehlgeschlagen (Exit Code: $($process.ExitCode), Fallback: $($fallbackProcess.ExitCode))"
                if ($errorOutput) {
                    $errorMsg += "`nFehlerdetails: $errorOutput"
                }
                Write-Host "Debug: $errorMsg" -ForegroundColor Red
                throw $errorMsg
            }
        }
    }
    catch {
        $statusLabel.Text = "Fehler aufgetreten!"
        $progressBar.Value = 0
        $videoList.Items[$videoList.Items.Count - 1] = "$url - ❌ FEHLER"
        [System.Windows.Forms.MessageBox]::Show("Fehler bei der Verarbeitung: $($_.Exception.Message)", "Fehler", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
    finally {
        $script:isProcessing = $false
        $statusLabel.Text = "Bereit für nächstes Video"
        $progressBar.Value = 0
    }
}

# --- 6) GUI erstellen ---
function Show-YouTubeConverterGUI {
    # PowerShell-Konsole sichtbar machen für Debug-Ausgaben
    Add-Type -Name ConsoleUtils -Namespace Win32 -MemberDefinition @'
        [DllImport("kernel32.dll")]
        public static extern IntPtr GetConsoleWindow();
        [DllImport("user32.dll")]
        public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
'@
    $consoleWindow = [Win32.ConsoleUtils]::GetConsoleWindow()
    [Win32.ConsoleUtils]::ShowWindow($consoleWindow, 1) # 1 = SW_SHOW
    
    Write-Host "=== YouTube Video Converter gestartet ===" -ForegroundColor Green
    Write-Host "Debug-Informationen werden hier angezeigt..." -ForegroundColor Yellow
    # Hauptfenster erstellen
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "YouTube Video Converter"
    $form.Size = New-Object System.Drawing.Size(600, 500)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    
    # URL-Eingabe
    $urlLabel = New-Object System.Windows.Forms.Label
    $urlLabel.Location = New-Object System.Drawing.Point(20, 20)
    $urlLabel.Size = New-Object System.Drawing.Size(200, 20)
    $urlLabel.Text = "YouTube URL eingeben:"
    $form.Controls.Add($urlLabel)
    
    $urlTextBox = New-Object System.Windows.Forms.TextBox
    $urlTextBox.Location = New-Object System.Drawing.Point(20, 45)
    $urlTextBox.Size = New-Object System.Drawing.Size(400, 25)
    $urlTextBox.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $form.Controls.Add($urlTextBox)
    
    # Start Button
    $startButton = New-Object System.Windows.Forms.Button
    $startButton.Location = New-Object System.Drawing.Point(440, 45)
    $startButton.Size = New-Object System.Drawing.Size(120, 25)
    $startButton.Text = "Video herunterladen"
    $startButton.BackColor = [System.Drawing.Color]::LightGreen
    $startButton.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($startButton)
    
    # Status Label
    $statusLabel = New-Object System.Windows.Forms.Label
    $statusLabel.Location = New-Object System.Drawing.Point(20, 85)
    $statusLabel.Size = New-Object System.Drawing.Size(540, 20)
    $statusLabel.Text = "Bereit - Geben Sie eine YouTube URL ein und klicken Sie auf 'Video herunterladen'"
    $statusLabel.ForeColor = [System.Drawing.Color]::Blue
    $form.Controls.Add($statusLabel)
    
    # Fortschrittsbalken
    $progressBar = New-Object System.Windows.Forms.ProgressBar
    $progressBar.Location = New-Object System.Drawing.Point(20, 110)
    $progressBar.Size = New-Object System.Drawing.Size(540, 25)
    $progressBar.Style = "Continuous"
    $form.Controls.Add($progressBar)
    
    # Video-Liste Label
    $listLabel = New-Object System.Windows.Forms.Label
    $listLabel.Location = New-Object System.Drawing.Point(20, 150)
    $listLabel.Size = New-Object System.Drawing.Size(200, 20)
    $listLabel.Text = "Verarbeitete Videos:"
    $form.Controls.Add($listLabel)
    
    # Video-Liste
    $videoListBox = New-Object System.Windows.Forms.ListBox
    $videoListBox.Location = New-Object System.Drawing.Point(20, 175)
    $videoListBox.Size = New-Object System.Drawing.Size(540, 180)
    $videoListBox.Font = New-Object System.Drawing.Font("Consolas", 9)
    $form.Controls.Add($videoListBox)
    
    # Ordner öffnen Button
    $openFolderButton = New-Object System.Windows.Forms.Button
    $openFolderButton.Location = New-Object System.Drawing.Point(20, 370)
    $openFolderButton.Size = New-Object System.Drawing.Size(150, 30)
    $openFolderButton.Text = "Ordner öffnen"
    $openFolderButton.BackColor = [System.Drawing.Color]::LightBlue
    $form.Controls.Add($openFolderButton)
    
    # Beenden Button
    $exitButton = New-Object System.Windows.Forms.Button
    $exitButton.Location = New-Object System.Drawing.Point(480, 370)
    $exitButton.Size = New-Object System.Drawing.Size(80, 30)
    $exitButton.Text = "Beenden"
    $exitButton.BackColor = [System.Drawing.Color]::LightCoral
    $form.Controls.Add($exitButton)
    
    # Event-Handler
    $startButton.Add_Click({
        $url = $urlTextBox.Text.Trim()
        if ([string]::IsNullOrEmpty($url)) {
            [System.Windows.Forms.MessageBox]::Show("Bitte geben Sie eine YouTube URL ein.", "Hinweis", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }
        
        if ($url -notmatch "youtube\.com|youtu\.be") {
            [System.Windows.Forms.MessageBox]::Show("Bitte geben Sie eine gültige YouTube URL ein.", "Hinweis", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }
        
        $urlTextBox.Text = ""
        Start-VideoProcessing -url $url -progressBar $progressBar -statusLabel $statusLabel -videoList $videoListBox
    })
    
    $openFolderButton.Add_Click({
        Start-Process explorer.exe $baseDir
    })
    
    $exitButton.Add_Click({
        $form.Close()
    })
    
    # Enter-Taste für URL-Eingabe
    $urlTextBox.Add_KeyDown({
        if ($_.KeyCode -eq "Enter") {
            $startButton.PerformClick()
        }
    })
    
    # Fenster anzeigen
    $form.ShowDialog()
}

# --- 7) GUI starten ---
if ($GUI) {
    Show-YouTubeConverterGUI
}
