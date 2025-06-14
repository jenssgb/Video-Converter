import os
import subprocess
import tkinter as tk
from tkinter import messagebox, StringVar
from pytube import YouTube
import re

def download_video(url, output_path=None):
    """
    Download YouTube video using pytube
    """
    try:
        yt = YouTube(url)
        video_title = yt.title
        # Säubern des Titels für die Verwendung als Dateiname
        safe_title = re.sub(r'[\\/*?:"<>|]', "", video_title)
        
        if not output_path:
            output_path = os.path.join(os.path.expanduser("~"), "Downloads")
        
        # Herunterladen des Videos in bestmöglicher Qualität
        video = yt.streams.filter(progressive=True, file_extension='mp4').order_by('resolution').desc().first()
        downloaded_file = video.download(output_path=output_path, filename=f"{safe_title}.mp4")
        
        return downloaded_file, safe_title
    
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

# GUI erstellen
root = tk.Tk()
root.title("YouTube Video Downloader & Converter")
root.geometry("500x200")
root.resizable(False, False)

# Frames
url_frame = tk.Frame(root)
url_frame.pack(pady=20)

button_frame = tk.Frame(root)
button_frame.pack(pady=10)

status_frame = tk.Frame(root)
status_frame.pack(pady=10)

# URL Eingabe
tk.Label(url_frame, text="YouTube URL:").grid(row=0, column=0, padx=5)
url_var = StringVar()
url_entry = tk.Entry(url_frame, textvariable=url_var, width=50)
url_entry.grid(row=0, column=1, padx=5)

# Download Button
download_button = tk.Button(button_frame, text="Download & Convert", 
                           command=lambda: process_url(url_var.get()))
download_button.pack()

# Status Label
status_label = tk.Label(status_frame, text="Bereit zum Herunterladen...")
status_label.pack()

# Start the GUI
if __name__ == "__main__":
    root.mainloop()
