"""
services/audio.py
استخراج الصوت بصيغة MP3 من الفيديو باستخدام yt-dlp + ffmpeg
"""

import os
import uuid
import asyncio
import yt_dlp

from config import config
from utils.cookies_manager import get_ydl_cookie_opts

DOWNLOAD_DIR = config.DOWNLOAD_DIR


def _download_audio_sync(url: str, out_template: str, site: str = None) -> None:
    opts = {
        "outtmpl": out_template,
        "format": "bestaudio/best",
        "quiet": True,
        "no_warnings": True,
        "noplaylist": True,
        "socket_timeout": config.DOWNLOAD_TIMEOUT,
        "postprocessors": [
            {
                "key": "FFmpegExtractAudio",
                "preferredcodec": "mp3",
                "preferredquality": "192",
            }
        ],
    }
    if site:
        opts.update(get_ydl_cookie_opts(site))
    if config.PROXY_URL:
        opts["proxy"] = config.PROXY_URL
    with yt_dlp.YoutubeDL(opts) as ydl:
        ydl.download([url])


async def download_audio(url: str) -> str:
    """
    استخراج الصوت من الرابط وتحويله إلى MP3
    يرجع مسار ملف MP3 النهائي
    """
    from utils.validators import detect_site

    site = detect_site(url)
    file_id = uuid.uuid4().hex[:10]
    out_template = os.path.join(DOWNLOAD_DIR, f"{file_id}.%(ext)s")

    loop = asyncio.get_event_loop()
    await loop.run_in_executor(None, _download_audio_sync, url, out_template, site)

    expected_path = os.path.join(DOWNLOAD_DIR, f"{file_id}.mp3")
    if os.path.exists(expected_path):
        return expected_path

    # fallback لو الامتداد اختلف لأي سبب
    for f in os.listdir(DOWNLOAD_DIR):
        if f.startswith(file_id):
            return os.path.join(DOWNLOAD_DIR, f)

    raise FileNotFoundError("فشل استخراج الصوت - لم يتم العثور على الملف الناتج")

