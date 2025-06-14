# YouTube Video Downloader und VLC Transcoder

Eine Python-Anwendung, die YouTube-Videos herunterladen und mit VLC im Hintergrundmodus transcodieren kann.

## Voraussetzungen

1. Python 3.6 oder höher
2. VLC Media Player installiert
3. Die benötigten Python-Pakete (siehe `requirements.txt`)

## Installation

1. Klone dieses Repository oder lade die Dateien herunter
2. Installiere die benötigten Pakete:

```
pip install -r requirements.txt
```

3. Stelle sicher, dass VLC Media Player installiert ist

## Verwendung

1. Führe die Anwendung aus:

```
python youtube_converter.py
```

2. Füge die YouTube-URL ein und klicke auf "Download & Convert"
3. Das transkodierte Video wird auf dem Desktop im Ordner "YouTubeConverter" gespeichert

## Konfiguration

Die Transkodierungsparameter sind wie folgt konfiguriert:
- Videocodec: fmp4
- Videobitrate: 1800 kbps
- FPS: 24
- Skalierung: 0.5 (50%)
- Audiocodec: mp2a
- Audiobitrate: 320 kbps
- Audiokanäle: 2
- Abtastrate: 48000 Hz
