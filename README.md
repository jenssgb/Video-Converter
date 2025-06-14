# Video Converter

## Einfache Verwendung

### Methode 1: Batch-Datei
Doppelklick auf `Start-VideoConverter.bat`

### Methode 2: PowerShell-Befehl
Kopieren Sie den folgenden Befehl in eine PowerShell und führen Sie ihn aus:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process PowerShell -Verb RunAs -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-NoExit','-Command','iex (irm https://raw.githubusercontent.com/jenssgb/Video-Converter/main/Init-VideoConverter.ps1)')"
```

## Wichtig
Achten Sie darauf, nur den obigen Befehl zu kopieren, ohne Prompt-Zeilen wie "PS C:\Users\..." 
