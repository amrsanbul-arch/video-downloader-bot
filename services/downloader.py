"""
services/downloader.py
الخدمة الأساسية للتحميل عبر yt-dlp - تحليل الرابط، استخراج المعلومات، وتحميل الفيديو/الصوت
"""

import os
import uuid
import asyncio
import yt_dlp

from config import config
from utils.cookies_manager import get_cookie_path

DOWNLOAD_DIR = config.DOWNLOAD_DIR


def _build_ydl_opts(out_path: str, fmt: str = "best", site: str = None) -> dict:
    """إعدادات yt-dlp الأساسية المشتركة"""
    opts = {
        "outtmpl": out_path,
        "format": fmt,
        "quiet": True,
        "no_warnings": True,
        "noplaylist": True,
        "merge_output_format": "mp4",
        "socket_timeout": config.DOWNLOAD_TIMEOUT,
    }
    cookie_path = get_cookie_path(site) if site else (config.COOKIES_FILE or None)
    if cookie_path:
        opts["cookiefile"] = cookie_path
    return opts


def _extract_info_sync(url: str, site: str = None) -> dict:
    """استخراج معلومات الفيديو بدون تحميل (تشغيل sync داخل thread)"""
    opts = {
        "quiet": True,
        "no_warnings": True,
        "noplaylist": True,
        "skip_download": True,
    }
    cookie_path = get_cookie_path(site) if site else (config.COOKIES_FILE or None)
    if cookie_path:
        opts["cookiefile"] = cookie_path
    with yt_dlp.YoutubeDL(opts) as ydl:
        info = ydl.extract_info(url, download=False)
        return info


async def get_video_info(url: str) -> dict:
    """
    إرجاع معلومات الفيديو الأساسية: العنوان، المدة، الحجم التقريبي، الصورة المصغرة
    """
    from utils.validators import detect_site  # استيراد محلي لتجنب أي حلقة استيراد

    site = detect_site(url)
    loop = asyncio.get_event_loop()
    info = await loop.run_in_executor(None, _extract_info_sync, url, site)

    # تقدير الحجم لأعلى جودة متاحة
    filesize = info.get("filesize") or info.get("filesize_approx")
    if not filesize:
        formats = info.get("formats", [])
        sizes = [f.get("filesize") or f.get("filesize_approx") for f in formats]
        sizes = [s for s in sizes if s]
        filesize = max(sizes) if sizes else 0

    return {
        "id": info.get("id"),
        "title": info.get("title", "بدون عنوان"),
        "duration": info.get("duration", 0),
        "filesize": filesize,
        "thumbnail": info.get("thumbnail"),
        "webpage_url": info.get("webpage_url", url),
        "extractor": info.get("extractor_key", "Unknown"),
        "uploader": info.get("uploader") or info.get("channel") or "—",
        "abr": info.get("abr") or 128,
        "height": info.get("height") or 0,
    }


def _download_sync(url: str, out_path: str, fmt: str, height: int = None, site: str = None) -> str:
    opts = _build_ydl_opts(out_path, fmt, site)
    if height:
        opts["format"] = f"bestvideo[height<={height}]+bestaudio/best[height<={height}]/best"
    with yt_dlp.YoutubeDL(opts) as ydl:
        ydl.download([url])
    return out_path


async def download_video(url: str, quality: str = "high", height: int = None) -> str:
    """
    تحميل الفيديو بجودة معينة:
    quality: 'high', 'medium', أو 'custom'
    height: الارتفاع بالبكسل (480, 720, 1080, 2160)
    يرجع مسار الملف النهائي
    """
    from utils.validators import detect_site

    site = detect_site(url)
    file_id = uuid.uuid4().hex[:10]
    out_template = os.path.join(DOWNLOAD_DIR, f"{file_id}.%(ext)s")

    # إذا حددوا ارتفاع محدد
    if height:
        fmt = f"bestvideo[height<={height}]+bestaudio/best[height<={height}]/best"
    elif quality == "medium":
        fmt = "bestvideo[height<=480]+bestaudio/best[height<=480]/best"
    elif quality == "custom":
        fmt = "best"
    else:  # high
        fmt = "bestvideo[height<=1080]+bestaudio/best[height<=1080]/best"

    loop = asyncio.get_event_loop()
    await loop.run_in_executor(None, _download_sync, url, out_template, fmt, height, site)

    # تحديد المسار النهائي الحقيقي بعد التحميل (الامتداد قد يتغير)
    for f in os.listdir(DOWNLOAD_DIR):
        if f.startswith(file_id):
            return os.path.join(DOWNLOAD_DIR, f)

    raise FileNotFoundError("فشل تحميل الفيديو - لم يتم العثور على الملف الناتج")


async def get_quality_estimates(url: str) -> dict:
    """
    إرجاع قاموس {height: estimated_filesize_bytes} لكل جودة متاحة فعليًا للفيديو
    """
    from utils.validators import detect_site

    site = detect_site(url)
    loop = asyncio.get_event_loop()
    info = await loop.run_in_executor(None, _extract_info_sync, url, site)

    formats = info.get("formats", [])
    estimates: dict[int, int] = {}

    for fmt in formats:
        height = fmt.get("height")
        if not height:
            continue
        size = fmt.get("filesize") or fmt.get("filesize_approx") or 0
        if size and (height not in estimates or size > estimates[height]):
            estimates[height] = size

    return estimates


def cleanup_file(path: str):
    """حذف الملف المؤقت بعد إرساله للمستخدم"""
    try:
        if path and os.path.exists(path):
            os.remove(path)
    except OSError:
        pass

