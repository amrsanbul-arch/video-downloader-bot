#!/data/data/com.termux/files/usr/bin/bash
# fix_bugs.sh
# سكريبت يطبق إصلاحات الأخطاء الثلاثة تلقائيًا على مشروع video_bot

set -e

echo "🔧 بدء تطبيق الإصلاحات..."

# ===== إصلاح 1: bot.py =====
cat > bot.py << 'EOF'
"""
bot.py - النسخة 2.1 (مصححة)
"""
from telegram import Update
from telegram.ext import (
    Application, CommandHandler, MessageHandler, CallbackQueryHandler,
    ContextTypes, filters,
)
from config import config
from database.models import db
from utils.logger import logger
from handlers import start, help as help_handler, settings, admin, download
from handlers import admin_dashboard, force_subscribe

async def on_error(update: object, context: ContextTypes.DEFAULT_TYPE):
    logger.error(f"حدث خطأ غير متوقع: {context.error}", exc_info=context.error)

async def post_init(application: Application):
    await db.connect()
    logger.info("✅ تم الاتصال بقاعدة البيانات بنجاح")

async def post_shutdown(application: Application):
    await db.close()
    logger.info("🔌 تم إغلاق الاتصال بقاعدة البيانات")

def main():
    config.validate()
    logger.info("🚀 بدء تشغيل البوت...")

    app = (
        Application.builder()
        .token(config.BOT_TOKEN)
        .post_init(post_init)
        .post_shutdown(post_shutdown)
        .build()
    )

    app.add_handler(CommandHandler("start", start.cmd_start))
    app.add_handler(CommandHandler("about", start.cmd_about))
    app.add_handler(CommandHandler("ping", start.cmd_ping))
    app.add_handler(CommandHandler("lang", start.cmd_lang))
    app.add_handler(CallbackQueryHandler(start.on_lang_callback, pattern="^setlang_"))
    app.add_handler(CommandHandler("help", help_handler.cmd_help))
    app.add_handler(CommandHandler("settings", settings.cmd_settings))
    app.add_handler(CommandHandler("stats", settings.cmd_stats))

    app.add_handler(CommandHandler("users", admin.cmd_users))
    app.add_handler(CommandHandler("botstats", admin.cmd_botstats))
    app.add_handler(CommandHandler("ban", admin.cmd_ban))
    app.add_handler(CommandHandler("unban", admin.cmd_unban))
    app.add_handler(CommandHandler("broadcast", admin.cmd_broadcast))
    app.add_handler(CommandHandler("logs", admin.cmd_logs))
    app.add_handler(CommandHandler("restart", admin.cmd_restart))
    app.add_handler(CommandHandler("update", admin.cmd_update))

    app.add_handler(CommandHandler("admin", admin_dashboard.cmd_admin))
    app.add_handler(CallbackQueryHandler(admin_dashboard.on_admin_callback, pattern="^admin_"))

    async def on_text_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
        pending_action = context.user_data.get("admin_action")
        if pending_action and await admin_dashboard.is_admin_check(update):
            await admin_dashboard.on_admin_text_input(update, context)
            return
        if not await force_subscribe.check_subscription(update, context):
            await force_subscribe.send_subscribe_message(update, context)
            return
        await download.on_message(update, context)

    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, on_text_message))
    app.add_handler(CallbackQueryHandler(download.on_download_callback, pattern="^dl"))

    app.add_error_handler(on_error)
    logger.info("✅ البوت شغال دلوقتي...")
    app.run_polling(allowed_updates=Update.ALL_TYPES)

if __name__ == "__main__":
    main()
EOF
echo "✅ تم إصلاح bot.py"

# ===== إصلاح 2: handlers/download.py =====
cat > handlers/download.py << 'PYEOF'
"""
handlers/download.py
استقبال الروابط، عرض معلومات الفيديو، اختيار جودة دقيقة، وتحميل محسّن
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
from utils.helpers import rate_limiter, format_size, format_duration
from services.downloader import get_video_info, download_video, cleanup_file
from services.audio import download_audio
from services.thumbnail import download_thumbnail

_pending_urls: dict[str, str] = {}


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


def _build_quality_keyboard(short_id: str) -> InlineKeyboardMarkup:
    return InlineKeyboardMarkup(
        [
            [InlineKeyboardButton("🎥 2160p (4K)", callback_data=f"dlq_2160_{short_id}")],
            [InlineKeyboardButton("🎬 1080p (Full HD)", callback_data=f"dlq_1080_{short_id}")],
            [InlineKeyboardButton("📱 720p (HD)", callback_data=f"dlq_720_{short_id}")],
            [InlineKeyboardButton("📞 480p (Mobile)", callback_data=f"dlq_480_{short_id}")],
            [InlineKeyboardButton("🎵 صوت MP3", callback_data=f"dl_audio_{short_id}")],
            [InlineKeyboardButton("🖼 صورة مصغرة", callback_data=f"dl_thumb_{short_id}")],
            [InlineKeyboardButton("❌ إلغاء", callback_data=f"dl_cancel_{short_id}")],
        ]
    )


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

    status_msg = await update.message.reply_text(t("analyzing", lang))

    try:
        info = await get_video_info(url)
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

    caption = _build_caption(info)
    keyboard = _build_quality_keyboard(short_id)
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
        await query.edit_message_text("⏳ جاري التحميل...\n\n[░░░░░░░░░░] 0%")
    except Exception:
        pass

    file_path = None
    try:
        if action in ["2160", "1080", "720", "480"]:
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
PYEOF
echo "✅ تم إصلاح handlers/download.py"

# ===== إصلاح 3: handlers/force_subscribe.py =====
cat > handlers/force_subscribe.py << 'EOF'
"""
handlers/force_subscribe.py
نظام Force Subscribe
"""

from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import ContextTypes
from telegram.error import TelegramError

from config import config
from utils.logger import logger


async def check_subscription(update: Update, context: ContextTypes.DEFAULT_TYPE) -> bool:
    channel = getattr(config, "FORCE_SUBSCRIBE_CHANNEL", None)
    if not channel:
        return True

    user_id = update.effective_user.id
    chat_id = channel if channel.startswith("@") else f"@{channel}"

    try:
        member = await context.bot.get_chat_member(chat_id=chat_id, user_id=user_id)
        if member.status in ["member", "administrator", "creator"]:
            return True
    except TelegramError:
        logger.warning(f"فشل التحقق من اشتراك المستخدم {user_id} في القناة {channel}")
    except Exception as e:
        logger.error(f"خطأ في check_subscription: {e}")

    return False


async def send_subscribe_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    channel = getattr(config, "FORCE_SUBSCRIBE_CHANNEL", None)
    if not channel:
        return

    keyboard = InlineKeyboardMarkup(
        [[InlineKeyboardButton("✅ اشترك في القناة", url=f"https://t.me/{channel}")]]
    )

    await update.message.reply_text(
        "🔒 لازم تكون مشترك في القناة قبل ما تحمّل!\n\nاشترك في القناة وحاول تاني.",
        reply_markup=keyboard,
    )
EOF
echo "✅ تم إصلاح handlers/force_subscribe.py"

# ===== فحص الصياغة =====
echo "🔍 فحص الأكواد..."
python -m py_compile bot.py handlers/download.py handlers/force_subscribe.py

echo ""
echo "✅✅✅ تم تطبيق كل الإصلاحات بنجاح! ✅✅✅"
echo ""
echo "الخطوة الجاية:"
echo "  git add ."
echo "  git commit -m 'Fix critical bugs'"
echo "  git push"
echo "  python bot.py"
