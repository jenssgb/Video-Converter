import os
import subprocess
import tkinter as tk
from tkinter import messagebox, StringVar
import re
import yt_dlp

def download_video(url, output_path=None):
    """
    Download YouTube video using yt-dlp
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