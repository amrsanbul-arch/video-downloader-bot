#!/data/data/com.termux/files/usr/bin/bash
# new_analysis_style.sh
set -e
echo "🔧 تطبيق ستايل التحليل الجديد..."

mkdir -p $(dirname 'services/downloader.py')
cat > 'services/downloader.py' << 'ZEOF_MARKER_UNIQUE'
"""
services/downloader.py
الخدمة الأساسية للتحميل عبر yt-dlp - تحليل الرابط، استخراج المعلومات، وتحميل الفيديو/الصوت
"""

import os
import uuid
import asyncio
import yt_dlp

from config import config

DOWNLOAD_DIR = config.DOWNLOAD_DIR


def _build_ydl_opts(out_path: str, fmt: str = "best") -> dict:
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
    if config.COOKIES_FILE:
        opts["cookiefile"] = config.COOKIES_FILE
    return opts


def _extract_info_sync(url: str) -> dict:
    """استخراج معلومات الفيديو بدون تحميل (تشغيل sync داخل thread)"""
    opts = {
        "quiet": True,
        "no_warnings": True,
        "noplaylist": True,
        "skip_download": True,
    }
    if config.COOKIES_FILE:
        opts["cookiefile"] = config.COOKIES_FILE
    with yt_dlp.YoutubeDL(opts) as ydl:
        info = ydl.extract_info(url, download=False)
        return info


async def get_video_info(url: str) -> dict:
    """
    إرجاع معلومات الفيديو الأساسية: العنوان، المدة، الحجم التقريبي، الصورة المصغرة
    """
    loop = asyncio.get_event_loop()
    info = await loop.run_in_executor(None, _extract_info_sync, url)

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


def _download_sync(url: str, out_path: str, fmt: str, height: int = None) -> str:
    opts = _build_ydl_opts(out_path, fmt)
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
    await loop.run_in_executor(None, _download_sync, url, out_template, fmt, height)

    # تحديد المسار النهائي الحقيقي بعد التحميل (الامتداد قد يتغير)
    for f in os.listdir(DOWNLOAD_DIR):
        if f.startswith(file_id):
            return os.path.join(DOWNLOAD_DIR, f)

    raise FileNotFoundError("فشل تحميل الفيديو - لم يتم العثور على الملف الناتج")


async def get_quality_estimates(url: str) -> dict:
    """
    إرجاع قاموس {height: estimated_filesize_bytes} لكل جودة متاحة فعليًا للفيديو
    """
    loop = asyncio.get_event_loop()
    info = await loop.run_in_executor(None, _extract_info_sync, url)

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

ZEOF_MARKER_UNIQUE
echo "✅ تم تحديث services/downloader.py"

mkdir -p $(dirname 'handlers/download.py')
cat > 'handlers/download.py' << 'ZEOF_MARKER_UNIQUE'
"""
handlers/download.py
استقبال الروابط، تحليل مفصّل، شبكة جودات كاملة (144p → 1080p + Best)
"""

import uuid
import html
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import ContextTypes

from config import config
from database.models import db
from utils.logger import logger
from utils.i18n import t
from utils.validators import is_valid_url, detect_site, extract_first_url
from utils.helpers import rate_limiter, format_duration
from services.downloader import (
    get_video_info,
    get_quality_estimates,
    download_video,
    cleanup_file,
)
from services.audio import download_audio
from services.thumbnail import download_thumbnail
from handlers.menu import get_default_quality

_pending_urls: dict[str, str] = {}

QUALITY_GRID = [144, 240, 360, 480, 720, 1080]


async def get_lang(user_id: int) -> str:
    return await db.get_user_language(user_id)


def _kb_str(size_bytes: int) -> str:
    """تنسيق الحجم بالكيلوبايت/ميجابايت بدقّة عشرية (لمطابقة ستايل التحليل)"""
    if not size_bytes:
        return "—"
    kb = size_bytes / 1024
    if kb < 1024:
        return f"{kb:.2f} KB"
    return f"{kb / 1024:.2f} MB"


def _build_analysis_caption(info: dict, site: str, estimates: dict) -> str:
    title = html.escape(info["title"])
    duration = format_duration(info["duration"])
    uploader = html.escape(str(info.get("uploader", "—")))
    default_height = info.get("height") or 0
    abr = int(info.get("abr") or 128)

    lines = [
        "🔍 <b>تم التحليل</b>\n",
        f"• المنصة: {site}",
        f"• العنوان: {title}",
        f"• المدة: {duration}",
        f"• القناة/الناشر: {uploader}",
        f"• الجودة الافتراضية: {default_height if default_height else '—'}",
        f"• الصوت الافتراضي: {abr}kbps",
        "",
        "أحجام تقديرية:",
    ]

    if estimates:
        for height in sorted(estimates.keys()):
            lines.append(f"• {height}p ≈ {_kb_str(estimates[height])}")
    else:
        lines.append("• غير متوفرة")

    lines.append("")
    lines.append("اختر نوع التحميل:")

    return "\n".join(lines)


def _build_quality_keyboard(short_id: str, default_quality: str = "") -> InlineKeyboardMarkup:
    """شبكة جودات 3×2 + Best + صوت/صورة + رجوع"""
    def label(height: int) -> str:
        text = f"{height}p"
        return f"⭐ {text}" if default_quality == str(height) else text

    rows = []
    for i in range(0, len(QUALITY_GRID), 3):
        row = [
            InlineKeyboardButton(label(h), callback_data=f"dlq_{h}_{short_id}")
            for h in QUALITY_GRID[i : i + 3]
        ]
        rows.append(row)

    rows.append([InlineKeyboardButton("⚡ Best", callback_data=f"dlq_best_{short_id}")])
    rows.append(
        [
            InlineKeyboardButton("🎵 صوت MP3", callback_data=f"dl_audio_{short_id}"),
            InlineKeyboardButton("🖼 صورة مصغرة", callback_data=f"dl_thumb_{short_id}"),
        ]
    )
    rows.append([InlineKeyboardButton("🔙 رجوع", callback_data=f"dl_cancel_{short_id}")])

    return InlineKeyboardMarkup(rows)


async def on_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    await db.add_or_update_user(user.id, user.username or "", user.first_name or "")

    if await db.is_banned(user.id):
        lang = await get_lang(user.id)
        await update.message.reply_text(t("banned", lang))
        return

    lang = await get_lang(user.id)

    if not rate_limiter.is_allowed(user.id):
        await update.message.reply_text(t("rate_limited", lang))
        return

    text = update.message.text or ""
    url = extract_first_url(text)

    if not url or not is_valid_url(url):
        await update.message.reply_text(t("invalid_url", lang))
        return

    status_msg = await update.message.reply_text("🔍 جاري التحليل...")

    try:
        info = await get_video_info(url)
        estimates = await get_quality_estimates(url)
    except Exception as e:
        logger.error(f"فشل تحليل الرابط {url}: {e}")
        err_text = str(e).lower()
        if "login" in err_text or "authentication" in err_text or "cookies" in err_text:
            await status_msg.edit_text(
                "🔒 هذا الفيديو يحتاج تسجيل دخول (الموقع طلب Cookies)."
            )
        else:
            await status_msg.edit_text("❌ تعذر تحليل هذا الرابط. تأكد إن الموقع مدعوم.")
        return

    short_id = uuid.uuid4().hex[:8]
    _pending_urls[short_id] = url

    site = detect_site(url)
    await db.log_download(user.id, url, site, "analyzed", "pending")

    default_quality = await get_default_quality(user.id)
    caption = _build_analysis_caption(info, site, estimates)
    keyboard = _build_quality_keyboard(short_id, default_quality)
    await status_msg.edit_text(caption, parse_mode="HTML", reply_markup=keyboard)


async def on_download_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()

    user_id = query.from_user.id

    data = query.data
    parts = data.split("_", 2)
    if len(parts) < 3:
        return

    prefix, action, short_id = parts[0], parts[1], parts[2]
    url = _pending_urls.get(short_id)

    if action == "cancel":
        _pending_urls.pop(short_id, None)
        await query.edit_message_text("❌ تم الإلغاء.")
        return

    if not url:
        await query.edit_message_text("⚠️ انتهت صلاحية هذا الطلب، ابعت الرابط تاني.")
        return

    try:
        await query.edit_message_text("✅ تم استلام طلبك.\n\nسأرسل الملف فور الانتهاء.")
    except Exception:
        pass

    file_path = None
    try:
        if action == "best":
            file_path = await download_video(url, quality="custom")
            await _send_with_size_check(query, context, file_path, is_video=True)
            format_name = "Best"

        elif action.isdigit():
            height = int(action)
            file_path = await download_video(url, quality="custom", height=height)
            await _send_with_size_check(query, context, file_path, is_video=True)
            format_name = f"{height}p"

        elif action == "audio":
            file_path = await download_audio(url)
            await _send_with_size_check(query, context, file_path, is_video=False)
            format_name = "MP3"

        elif action == "thumb":
            info = await get_video_info(url)
            file_path = await download_thumbnail(info.get("thumbnail"))
            with open(file_path, "rb") as f:
                await context.bot.send_photo(chat_id=query.message.chat_id, photo=f)
            format_name = "Thumbnail"
        else:
            format_name = action

        site = detect_site(url)
        await db.log_download(user_id, url, site, format_name, "success")
        _pending_urls.pop(short_id, None)

    except Exception as e:
        logger.error(f"فشل تنفيذ التحميل للرابط {url}: {e}")
        await context.bot.send_message(
            chat_id=query.message.chat_id,
            text="❌ حصل خطأ أثناء التحميل. حاول تاني أو جرب رابط مختلف.",
        )
        site = detect_site(url)
        await db.log_download(user_id, url, site, action, "failed")

    finally:
        if file_path:
            cleanup_file(file_path)


async def _send_with_size_check(query, context, file_path: str, is_video: bool):
    import os

    size_mb = os.path.getsize(file_path) / (1024 * 1024)
    if size_mb > config.MAX_FILE_SIZE_MB:
        await context.bot.send_message(
            chat_id=query.message.chat_id,
            text=f"⚠️ حجم الملف ({size_mb:.0f}MB) أكبر من الحد المسموح ({config.MAX_FILE_SIZE_MB}MB).",
        )
        return

    with open(file_path, "rb") as f:
        if is_video:
            await context.bot.send_video(chat_id=query.message.chat_id, video=f, supports_streaming=True)
        else:
            await context.bot.send_audio(chat_id=query.message.chat_id, audio=f)

ZEOF_MARKER_UNIQUE
echo "✅ تم تحديث handlers/download.py"

echo "🔍 فحص الأكواد..."
python -m py_compile services/downloader.py handlers/download.py
echo ""
echo "✅✅✅ تم تطبيق الستايل الجديد بنجاح! ✅✅✅"
echo ""
echo "الخطوة الجاية:"
echo "  git add ."
echo "  git commit -m 'New detailed analysis style with full quality grid'"
echo "  git push"
echo "  python bot.py   (أو bash run.sh)"