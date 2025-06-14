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
    
    try {
        # Video-Info zur Liste hinzufügen
        $videoItem = "$url - Download läuft..."
        $videoList.Items.Add($videoItem)
        $videoList.SelectedIndex = $videoList.Items.Count - 1
        
        # Download mit simuliertem Fortschritt
        $statusLabel.Text = "Lade Video herunter..."
        for ($i = 0; $i -le 50; $i += 10) {
            $progressBar.Value = $i
            Start-Sleep -Milliseconds 200
        }
        
        # Echter Download
        $process = Start-Process -FilePath "yt-dlp.exe" -ArgumentList "--newline", "-f", "bestvideo+bestaudio", "-o", "%(title)s.%(ext)s", $url -PassThru -NoNewWindow -RedirectStandardOutput "download.log" -RedirectStandardError "error.log"
        
        while (-not $process.HasExited) {
            Start-Sleep -Milliseconds 500
            $progressBar.Value = [Math]::Min(50, $progressBar.Value + 1)
        }
        
        if ($process.ExitCode -eq 0) {
            $progressBar.Value = 60
            $statusLabel.Text = "Download abgeschlossen, starte Konvertierung..."
            
            # Neueste Datei finden
            $latest = Get-ChildItem -File | Sort-Object CreationTime -Descending | Select-Object -First 1
            
            if ($latest) {
                # Transcoding
                $statusLabel.Text = "Konvertiere Video..."
                $outputFile = "_Converted_$($latest.BaseName).mp4"
                
                $transcodeProcess = Start-Process -FilePath "ffmpeg.exe" -ArgumentList "-i", $latest.FullName, "-c:v", "libx264", "-b:v", "1800k", "-vf", "scale=iw*0.5:ih*0.5,fps=24", "-c:a", "mp2", "-b:a", "320k", "-ac", "2", "-ar", "48000", "-y", $outputFile -PassThru -NoNewWindow
                
                while (-not $transcodeProcess.HasExited) {
                    Start-Sleep -Milliseconds 500
                    $progressBar.Value = [Math]::Min(100, $progressBar.Value + 2)
                }
                
                if ($transcodeProcess.ExitCode -eq 0) {
                    $progressBar.Value = 100
                    $statusLabel.Text = "Erfolgreich abgeschlossen!"
                    
                    # Status in der Liste aktualisieren
                    $videoList.Items[$videoList.Items.Count - 1] = "$url - ✅ FERTIG"
                    $script:processedVideos += @{URL = $url; Status = "Erfolgreich"; File = $outputFile}
                    
                    [System.Windows.Forms.MessageBox]::Show("Video erfolgreich heruntergeladen und konvertiert!`nDatei: $outputFile", "Erfolg", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                } else {
                    throw "Konvertierung fehlgeschlagen"
                }
            } else {
                throw "Keine heruntergeladene Datei gefunden"
            }
        } else {
            throw "Download fehlgeschlagen"
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
