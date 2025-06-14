```powershell
# Import der benötigten Module
. "$PSScriptRoot\RunspaceManager.ps1"
. "$PSScriptRoot\VideoProcessingHelper.ps1"

# Aktualisierte Start-Funktion für den Konvertierungsprozess
function Start-VideoProcessing {
    param (
        [string]$VideoSource,  # URL oder Dateipfad
        [string]$OutputPath,
        [string]$Format = "mp4"
    )
    
    # Status-UI aktualisieren
    $progressBar.Value = 0
    $progressBar.Visibility = "Visible"
    $statusLabel.Content = "Verarbeitung wird gestartet..."
    $startButton.IsEnabled = $false
    $cancelButton.Visibility = "Visible"
    
    # Callback für Fortschrittsberichte
    $progressCallback = {
        param($SourceEventArgs)
        
        $progressData = $SourceEventArgs.MessageData
        
        # Dispatcher verwenden, um UI-Thread zu aktualisieren
        $syncHash.Window.Dispatcher.Invoke([Action]{
            $syncHash.ProgressBar.Value = $progressData.PercentComplete
            $syncHash.StatusLabel.Content = $progressData.Status
            
            if ($progressData.Completed) {
                $syncHash.StartButton.IsEnabled = $true
                $syncHash.CancelButton.Visibility = "Collapsed"
            }
        })
    }
    
    # Callback für Abschluss
    $completedCallback = {
        param($Results, $Success, $ErrorInfo, $Cancelled)
        
        # Dispatcher verwenden, um UI-Thread zu aktualisieren
        $syncHash.Window.Dispatcher.Invoke([Action]{
            if ($Success) {
                $syncHash.StatusLabel.Content = "Verarbeitung erfolgreich abgeschlossen"
                [System.Windows.MessageBox]::Show("Die Videokonvertierung wurde erfolgreich abgeschlossen.", "Erfolg", "OK", "Information")
                
                # Optional: Öffne das Ausgabeverzeichnis
                if ($Results) {
                    Start-Process -FilePath "explorer.exe" -ArgumentList "/select,`"$Results`""
                }
            }
            elseif ($Cancelled) {
                $syncHash.StatusLabel.Content = "Verarbeitung abgebrochen"
            }
            else {
                $syncHash.StatusLabel.Content = "Fehler bei der Verarbeitung"
                [System.Windows.MessageBox]::Show("Bei der Videokonvertierung ist ein Fehler aufgetreten: $ErrorInfo", "Fehler", "OK", "Error")
            }
            
            $syncHash.ProgressBar.Value = 0
            $syncHash.StartButton.IsEnabled = $true
            $syncHash.CancelButton.Visibility = "Collapsed"
        })
        
        # Event-Handler entfernen
        Unregister-Event -SourceIdentifier "VideoProcessingProgress" -ErrorAction SilentlyContinue
    }
    
    # SyncHash für den Zugriff aus Callbacks erstellen
    $global:syncHash = @{
        Window = $window
        ProgressBar = $progressBar
        StatusLabel = $statusLabel
        StartButton = $startButton
        CancelButton = $cancelButton
    }
    
    # Asynchronen Prozess starten
    $global:currentRunspace = Start-AsyncVideoProcessing -InputVideoPath $VideoSource -OutputPath $OutputPath -Format $Format -OnCompleted $completedCallback -OnProgress $progressCallback
    
    # Abbruch-Button konfigurieren
    $cancelButton.Add_Click({
        if ($global:currentRunspace) {
            Stop-RunspaceOperation -RunspaceInfo $global:currentRunspace
            $statusLabel.Content = "Verarbeitung wird abgebrochen..."
        }
    })
}

```