import os
import subprocess
import tkinter as tk
from tkinter import messagebox, StringVar
import re
import yt_dlp

def download_video(url, output_path=None, browser=None):
    """
    Download YouTube video using yt-dlp with browser cookies
    """
    try:
        if not output_path:
            output_path = os.path.join(os.path.expanduser("~"), "Downloads")
        
        # Temporäre Dateien für den Download
        os.makedirs(output_path, exist_ok=True)
        
        # YoutubeDL Optionen
        ydl_opts = {
            'format': 'best[ext=mp4]',
            'outtmpl': os.path.join(output_path, '%(title)s.%(ext)s'),
            'quiet': False,
            'no_warnings': False
        }
        
        # Browser-Cookies hinzufügen, wenn angegeben
        if browser and browser != "Keiner":
            ydl_opts['cookiesfrombrowser'] = (browser.lower(), None, None, None)
        
        # Video herunterladen
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=True)
            video_title = info.get('title', 'video')
            # Säubern des Titels für die Verwendung als Dateiname
            safe_title = re.sub(r'[\\/*?:"<>|]', "", video_title)
            video_path = os.path.join(output_path, f"{safe_title}.mp4")
            
            # Überprüfen, ob die Datei existiert oder einen anderen Namen hat
            if not os.path.exists(video_path):
                for file in os.listdir(output_path):
                    if file.endswith(".mp4") and safe_title in file:
                        video_path = os.path.join(output_path, file)
                        break
        
        return video_path, safe_title
    
    except Exception as e:
        print(f"Ein Fehler ist aufgetreten: {e}")
        return None, None

def transcode_video(video_path, video_title):
    """
    Transcode video using VLC in command line mode
    """
    try:
        # Ausgabeordner erstellen
        output_dir = os.path.join(os.path.expanduser("~"), "Desktop", "YouTubeConverter")
        os.makedirs(output_dir, exist_ok=True)
        
        # Ausgabepfad für das transcodierte Video
        output_file = os.path.join(output_dir, f"{video_title}.mp4")
        
        # VLC-Pfad bestimmen (Windows)
        vlc_path = "C:\\Program Files\\VideoLAN\\VLC\\vlc.exe"
        # Prüfen ob 64-Bit oder 32-Bit Version
        if not os.path.exists(vlc_path):
            vlc_path = "C:\\Program Files (x86)\\VideoLAN\\VLC\\vlc.exe"
        
        # VLC-Befehl für das Transcodieren
        vlc_command = [
            vlc_path, 
            "-vvv", 
            video_path, 
            "--qt-start-minimized", 
            "--qt-notification=0", 
            f"--sout=#transcode{{vcodec=fmp4,vb=1800,fps=24,scale=0.5,acodec=mp2a,ab=320,channels=2,samplerate=48000}}:standard{{access=file,mux=mp4,dst={output_file}}}", 
            "vlc://quit"
        ]
        
        # VLC im Hintergrund ausführen
        subprocess.run(vlc_command, check=True)
        
        return output_file
    
    except Exception as e:
        print(f"Beim Transcodieren ist ein Fehler aufgetreten: {e}")
        return None

def process_url(url):
    """
    Main function to download and transcode video
    """
    status_label.config(text="Video wird heruntergeladen...")
    root.update()
    
    # Download video
    temp_dir = os.path.join(os.path.expanduser("~"), "Downloads", "YoutubeConverter_temp")
    os.makedirs(temp_dir, exist_ok=True)
    video_path, video_title = download_video(url, temp_dir)
    
    if not video_path:
        status_label.config(text="Fehler beim Herunterladen des Videos.")
        return
    
    status_label.config(text="Video wird transcodiert...")
    root.update()
    
    # Transcode video
    output_file = transcode_video(video_path, video_title)
    
    if output_file:
        status_label.config(text=f"Fertig! Video gespeichert als: {output_file}")
        # Temporäre Datei löschen
        try:
            os.remove(video_path)
        except:
            pass
    else:
        status_label.config(text="Fehler beim Transcodieren des Videos.")

if __name__ == "__main__":
    # GUI erstellen
    root = tk.Tk()
    root.title("YouTube Video Downloader & Converter")
    root.geometry("500x300")  # Mehr Platz für die Browser-Auswahl
    root.resizable(False, False)

    # Frames
    url_frame = tk.Frame(root)
    url_frame.pack(pady=10)

    browser_frame = tk.Frame(root)
    browser_frame.pack(pady=5)

    button_frame = tk.Frame(root)
    button_frame.pack(pady=10)

    status_frame = tk.Frame(root)
    status_frame.pack(pady=10)

    # URL Eingabe
    tk.Label(url_frame, text="YouTube URL:").grid(row=0, column=0, padx=5)
    url_entry = tk.Entry(url_frame, width=50)
    url_entry.grid(row=0, column=1, padx=5)

    # Browser Auswahl
    tk.Label(browser_frame, text="Browser für Cookies:").grid(row=0, column=0, padx=5)
    browser_var = tk.StringVar(root)
    browser_var.set("Keiner")  # Standardwert
    browser_options = ["Keiner", "Chrome", "Firefox", "Opera", "Edge", "Safari"]
    browser_dropdown = tk.OptionMenu(browser_frame, browser_var, *browser_options)
    browser_dropdown.grid(row=0, column=1, padx=5)

    # Buttons
    download_button = tk.Button(button_frame, text="Video herunterladen", 
                              command=lambda: process_url(url_entry.get()))
    download_button.grid(row=0, column=0, padx=10)

    convert_button = tk.Button(button_frame, text="In MP3 umwandeln", 
                             command=lambda: process_video(url_entry.get(), "mp3", browser_var.get()))
    convert_button.grid(row=0, column=1, padx=10)

    # Status
    status_var = tk.StringVar()
    status_var.set("Bereit")
    status_label = tk.Label(status_frame, textvariable=status_var)
    status_label.pack()

    # Prozessierungsfunktion
    def process_video(url, conversion_type=None, browser=None):
        if not url:
            status_var.set("Bitte eine YouTube URL eingeben")
            return

        # Status aktualisieren
        status_var.set("Download läuft...")
        root.update()

        # Video herunterladen
        video_path, video_title = download_video(url, browser=browser)
        
        if not video_path:
            status_var.set("Download fehlgeschlagen")
            return

        # Konvertierung, falls angefordert
        if conversion_type == "mp3":
            status_var.set("Konvertiere zu MP3...")
            root.update()
            
            mp3_path = convert_to_mp3(video_path)
            if mp3_path:
                status_var.set(f"MP3 gespeichert: {os.path.basename(mp3_path)}")
            else:
                status_var.set("Konvertierung fehlgeschlagen")
        else:
            status_var.set(f"Video gespeichert: {os.path.basename(video_path)}")

    root.mainloop()
