# RunspaceManager.ps1 - Verwaltet PowerShell-Runspaces für asynchrone Verarbeitung

# Erstellt einen neuen Runspace für asynchrone Operationen
function New-ProcessingRunspace {
    param (
        [ScriptBlock]$ScriptBlock,
        [hashtable]$Parameters,
        [scriptblock]$OnProgressChanged,
        [scriptblock]$OnCompleted
    )

    # Initialisieren der Runspace-Factory
    $runspacePool = [runspacefactory]::CreateRunspacePool(1, 3)
    $runspacePool.Open()

    # PowerShell-Instanz mit Skriptblock erstellen
    $powershell = [powershell]::Create()
    $powershell.RunspacePool = $runspacePool
    
    # Skriptblock und Parameter hinzufügen
    [void]$powershell.AddScript($ScriptBlock)
    if ($Parameters) {
        [void]$powershell.AddParameters($Parameters)
    }

    # Ereignishandler einrichten
    $asyncResult = $powershell.BeginInvoke()

    # Objekt zurückgeben, das alles für die spätere Bereinigung enthält
    return @{
        Runspace = $runspacePool
        PowerShell = $powershell
        AsyncResult = $asyncResult
        OnProgressChanged = $OnProgressChanged
        OnCompleted = $OnCompleted
    }
}

# Überprüft, ob ein Runspace-Job abgeschlossen ist
function Test-RunspaceCompleted {
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$RunspaceInfo
    )
    
    return $RunspaceInfo.AsyncResult.IsCompleted
}

# Beendet einen Runspace und sammelt die Ergebnisse
function Complete-Runspace {
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$RunspaceInfo
    )
    
    try {
        # Ergebnisse sammeln
        $results = $RunspaceInfo.PowerShell.EndInvoke($RunspaceInfo.AsyncResult)
        
        # Callback aufrufen, wenn vorhanden
        if ($RunspaceInfo.OnCompleted) {
            & $RunspaceInfo.OnCompleted -Results $results -Success $true
        }
        
        return $results
    }
    catch {
        Write-Error "Fehler beim Abschließen des Runspace: $_"
        if ($RunspaceInfo.OnCompleted) {
            & $RunspaceInfo.OnCompleted -Results $null -Success $false -ErrorInfo $_
        }
        return $null
    }
    finally {
        # Ressourcen bereinigen
        $RunspaceInfo.PowerShell.Dispose()
        $RunspaceInfo.Runspace.Close()
        $RunspaceInfo.Runspace.Dispose()
    }
}

# Erlaubt das Abbrechen einer laufenden Operation
function Stop-RunspaceOperation {
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$RunspaceInfo
    )
    
    try {
        $RunspaceInfo.PowerShell.Stop()
        if ($RunspaceInfo.OnCompleted) {
            & $RunspaceInfo.OnCompleted -Results $null -Success $false -Cancelled $true
        }
    }
    catch {
        Write-Error "Fehler beim Stoppen des Runspace: $_"
    }
    finally {
        # Ressourcen bereinigen
        $RunspaceInfo.PowerShell.Dispose()
        $RunspaceInfo.Runspace.Close()
        $RunspaceInfo.Runspace.Dispose()
    }
}

# Sendet ein Fortschrittssignal vom Runspace zur GUI
function Send-ProgressUpdate {
    param (
        [string]$Status,
        [int]$PercentComplete = -1,
        [string]$CurrentOperation = "",
        [switch]$Completed
    )
    
    # Event auslösen, das von der GUI abgefangen werden kann
    $progressEvent = New-Event -SourceIdentifier "VideoProcessingProgress" -MessageData @{
        Status = $Status
        PercentComplete = $PercentComplete
        CurrentOperation = $CurrentOperation
        Completed = $Completed.IsPresent
        Timestamp = Get-Date
    }
}
