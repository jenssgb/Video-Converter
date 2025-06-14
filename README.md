# Video Converter

## Installieren und Starten (Einzeiler)

Kopieren Sie einen der folgenden Befehle in eine PowerShell oder CMD und führen Sie ihn aus:

### Standard-Benutzerrechte:
```
powershell -Command "iex (iwr -UseBasicParsing https://raw.githubusercontent.com/jenssgb/Video-Converter/main/SimpleInit.ps1 | Select-Object -ExpandProperty Content)"
```

### Als Administrator ausführen (empfohlen):
```
powershell -Command "Start-Process powershell -ArgumentList '-NoExit -Command \"iex (iwr -UseBasicParsing https://raw.githubusercontent.com/jenssgb/Video-Converter/main/SimpleInit.ps1 | Select-Object -ExpandProperty Content)\"' -Verb RunAs"
```

## Wichtig
Achten Sie darauf, nur den obigen Befehl zu kopieren, ohne Prompt-Zeilen wie "PS C:\Users\..."
