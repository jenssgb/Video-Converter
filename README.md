# Video-Converter

Eine einfache Anwendung zum Herunterladen von YouTube-Videos und Konvertieren in MP3.

## Features

- Download von YouTube-Videos
- Konvertierung in MP3-Format
- Unterstützung für Browser-Cookies (gegen YouTube Bot-Erkennung)

## Installation

1. Dieses Repository klonen
2. Abhängigkeiten installieren:
   ```
   pip install -r requirements.txt
   ```

## Verwendung

1. Starte die Anwendung mit `python app.py`
2. Füge eine YouTube-URL ein
3. Wähle deinen Browser für Cookies (hilft bei Bot-Erkennungsproblemen)
4. Klicke "Video herunterladen" oder "In MP3 umwandeln"

## Abhängigkeiten

- yt-dlp
- ffmpeg (muss im Systempfad sein)
- tkinter
3. Das transkodierte Video wird auf dem Desktop im Ordner "YouTubeConverter" gespeichert

## Hinweis zur Bibliothek

Diese Anwendung verwendet yt-dlp anstelle von pytube, da es besser gepflegt wird und zuverlässiger mit YouTube-API-Änderungen umgeht.

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
