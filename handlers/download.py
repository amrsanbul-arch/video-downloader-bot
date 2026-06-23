"""
handlers/download.py
استقبال الروابط، عرض معلومات الفيديو، اختيار جودة دقيقة، وتحميل محسّن مع شريط تقدم
"""

import uuid
import html
import asyncio
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import ContextTypes

from config import config
from database.models import db
from utils.logger import logger
from utils.i18n import t
from utils.validators import is_valid_url, detect_site, extract_first_url
from utils.helpers import rate_limiter, format_size, format_duration
from services.downloader import (
    get_video_info,
    download_video,
    get_available_formats,
    cleanup_file,
)
from services.audio import download_audio
from services.thumbnail import download_thumbnail
from handlers.menu import get_default_quality

# تخزين مؤقت: يربط معرف قصير برابط الفيديو الكامل
_pending_urls: dict[str, str] = {}
# تخزين الفيديوهات المحملة مؤخراً (للكاش)
_downloaded_cache: dict[str, str] = {}


async def get_lang(user_id: int) -> str:
    return await db.get_user_language(user_id)


def _build_caption(info: dict) -> str:
    title = html.escape(info["title"])
    duration = format_duration(info["duration"])
    size = format_size(info["filesize"])
    return (
        f"🎬 <b>{title}</b>\n\n"
        f"⏱ المدة: {duration}\n"
        f"📦 الحجم التقريبي: {size}\n"
        f"🌐 المصدر: {info['extractor']}\n\n"
        f"اختر طريقة التحميل:"
    )


def _build_quality_keyboard(short_id: str, default_quality: str = "") -> InlineKeyboardMarkup:
    """بناء لوحة مفاتيح الجودات المتاحة، مع تمييز الجودة الافتراضية للمستخدم بنجمة"""
    def label(base: str, height: str) -> str:
        return f"⭐ {base}" if default_quality == height else base

    return InlineKeyboardMarkup(
        [
            [InlineKeyboardButton(label("🎥 2160p (4K)", "2160"), callback_data=f"dlq_2160_{short_id}")],
            [InlineKeyboardButton(label("🎬 1080p (Full HD)", "1080"), callback_data=f"dlq_1080_{short_id}")],
            [InlineKeyboardButton(label("📱 720p (HD)", "720"), callback_data=f"dlq_720_{short_id}")],
            [InlineKeyboardButton(label("📞 480p (Mobile)", "480"), callback_data=f"dlq_480_{short_id}")],
            [InlineKeyboardButton("🎵 صوت MP3", callback_data=f"dl_audio_{short_id}")],
            [InlineKeyboardButton("🖼 صورة مصغرة", callback_data=f"dl_thumb_{short_id}")],
            [InlineKeyboardButton("❌ إلغاء", callback_data=f"dl_cancel_{short_id}")],
        ]
    )


async def on_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """استقبال الرسائل النصية، استخراج الرابط، وعرض معلومات الفيديو"""
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

    status_msg = await update.message.reply_text(t("analyzing", lang))

    try:
        info = await get_video_info(url)
    except Exception as e:
        logger.error(f"فشل تحليل الرابط {url}: {e}")
        err_text = str(e).lower()
        if "login" in err_text or "authentication" in err_text or "cookies" in err_text:
            await status_msg.edit_text(
                "🔒 هذا الفيديو يحتاج تسجيل دخول (الموقع طلب Cookies). "
                "لازم تضيف ملف كوكيز في إعدادات البوت لتحميل هذا النوع من الروابط."
            )
        else:
            await status_msg.edit_text("❌ تعذر تحليل هذا الرابط. تأكد إن الموقع مدعوم.")
        return

    short_id = uuid.uuid4().hex[:8]
    _pending_urls[short_id] = url

    site = detect_site(url)
    await db.log_download(user.id, url, site, "analyzed", "pending")

    default_quality = await get_default_quality(user.id)
    caption = _build_caption(info)
    keyboard = _build_quality_keyboard(short_id, default_quality)
    await status_msg.edit_text(caption, parse_mode="HTML", reply_markup=keyboard)


async def on_download_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """التعامل مع ضغط المستخدم على أحد أزرار التحميل"""
    query = update.callback_query
    await query.answer()

    user_id = query.from_user.id
    lang = await get_lang(user_id)

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
        await query.edit_message_text("⏳ جاري التحميل...\n\n[░░░░░░░░░░] 0%")
    except Exception:
        pass  # لو فشل التعديل (مثلاً الرسالة قديمة جدًا)، نكمل عادي

    file_path = None
    try:
        # تحديد نوع الملف المطلوب
        if action in ["2160", "1080", "720", "480"]:  # جودة محددة
            height = int(action)
            file_path = await download_video(url, quality="custom", height=height)
            await _send_with_size_check(query, context, file_path, is_video=True)
            format_name = f"{action}p"

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
    """إرسال الملف للمستخدم بعد التأكد إنه ضمن الحد المسموح به"""
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
            await context.bot.send_video(
                chat_id=query.message.chat_id, video=f, supports_streaming=True
            )
        else:
            await context.bot.send_audio(chat_id=query.message.chat_id, audio=f)

