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
        await update.message.reply_text(t("banned", lang), parse_mode="HTML")
        return

    lang = await get_lang(user.id)

    if not rate_limiter.is_allowed(user.id):
        await update.message.reply_text(t("rate_limited", lang), parse_mode="HTML")
        return

    text = update.message.text or ""
    url = extract_first_url(text)

    if not url or not is_valid_url(url):
        await update.message.reply_text(t("invalid_url", lang), parse_mode="HTML")
        return

    status_msg = await update.message.reply_text("🔍 <b>جاري التحليل...</b>", parse_mode="HTML")

    try:
        info = await get_video_info(url)
        estimates = await get_quality_estimates(url)
    except Exception as e:
        logger.error(f"فشل تحليل الرابط {url}: {e}")
        err_text = str(e).lower()
        if "login" in err_text or "authentication" in err_text or "cookies" in err_text:
            await status_msg.edit_text(
                "🔒 <b>هذا الفيديو يحتاج تسجيل دخول</b>\n\nالموقع طلب Cookies.",
                parse_mode="HTML",
            )
        else:
            await status_msg.edit_text(
                "❌ <b>تعذر تحليل هذا الرابط</b>\n\nتأكد إن الموقع مدعوم.",
                parse_mode="HTML",
            )
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
        await query.edit_message_text("❌ <b>تم الإلغاء.</b>", parse_mode="HTML")
        return

    if not url:
        await query.edit_message_text(
            "⚠️ <b>انتهت صلاحية هذا الطلب</b>\n\nابعت الرابط تاني.", parse_mode="HTML"
        )
        return

    try:
        await query.edit_message_text(
            "✅ <b>تم استلام طلبك.</b>\n\nسأرسل الملف فور الانتهاء.",
            parse_mode="HTML",
        )
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
            text="❌ <b>حصل خطأ أثناء التحميل</b>\n\nحاول تاني أو جرب رابط مختلف.",
            parse_mode="HTML",
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
            text=(
                f"⚠️ <b>حجم الملف كبير جدًا</b>\n\n"
                f"• الحجم: {size_mb:.0f}MB\n"
                f"• الحد المسموح: {config.MAX_FILE_SIZE_MB}MB"
            ),
            parse_mode="HTML",
        )
        return

    with open(file_path, "rb") as f:
        if is_video:
            await context.bot.send_video(chat_id=query.message.chat_id, video=f, supports_streaming=True)
        else:
            await context.bot.send_audio(chat_id=query.message.chat_id, audio=f)

