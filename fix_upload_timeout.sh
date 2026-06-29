#!/data/data/com.termux/files/usr/bin/bash
# fix_upload_timeout.sh
set -e
echo "🔧 زيادة مهلة رفع الملفات الكبيرة..."

cat > 'bot.py' << 'ZEOF_MARKER_UNIQUE'
"""
bot.py - النسخة 2.4
- لوحة إدارة كاملة
- اختيار جودة دقيقة + جودة افتراضية
- Force Subscribe
- شريط تقدم
- قائمة أزرار ثابتة موسّعة
- زرار "تواصل مع المطور" يفتح شات تليجرام مباشر
"""

from telegram import Update
from telegram.ext import (
    Application,
    CommandHandler,
    MessageHandler,
    CallbackQueryHandler,
    ContextTypes,
    filters,
)

from config import config
from database.models import db
from utils.logger import logger

from handlers import start, help as help_handler, settings, admin, download
from handlers import admin_dashboard, force_subscribe, menu, cookies, status


async def on_error(update: object, context: ContextTypes.DEFAULT_TYPE):
    logger.error(f"حدث خطأ غير متوقع: {context.error}", exc_info=context.error)


async def post_init(application: Application):
    await db.connect()
    logger.info("✅ تم الاتصال بقاعدة البيانات بنجاح")


async def post_shutdown(application: Application):
    await db.close()
    logger.info("🔌 تم إغلاق الاتصال بقاعدة البيانات")


async def cmd_cancel(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """إلغاء أي عملية معلّقة (برودكاست/حظر من جانب الأدمن)"""
    context.user_data.pop("admin_action", None)
    await update.message.reply_text("✅ <b>تم الإلغاء.</b>", parse_mode="HTML")


def main():
    config.validate()
    logger.info("🚀 بدء تشغيل البوت...")

    app = (
        Application.builder()
        .token(config.BOT_TOKEN)
        .connect_timeout(30)
        .read_timeout(60)
        .write_timeout(180)
        .pool_timeout(60)
        .post_init(post_init)
        .post_shutdown(post_shutdown)
        .build()
    )

    # ===== أوامر عامة =====
    app.add_handler(CommandHandler("start", start.cmd_start))
    app.add_handler(CommandHandler("about", start.cmd_about))
    app.add_handler(CommandHandler("ping", start.cmd_ping))
    app.add_handler(CommandHandler("lang", start.cmd_lang))
    app.add_handler(CommandHandler("cancel", cmd_cancel))
    app.add_handler(CallbackQueryHandler(start.on_lang_callback, pattern="^setlang_"))

    app.add_handler(CommandHandler("help", help_handler.cmd_help))

    app.add_handler(CommandHandler("settings", settings.cmd_settings))
    app.add_handler(CommandHandler("stats", settings.cmd_stats))

    # ===== أوامر الإدارة (القديمة) =====
    app.add_handler(CommandHandler("users", admin.cmd_users))
    app.add_handler(CommandHandler("botstats", admin.cmd_botstats))
    app.add_handler(CommandHandler("ban", admin.cmd_ban))
    app.add_handler(CommandHandler("unban", admin.cmd_unban))
    app.add_handler(CommandHandler("broadcast", admin.cmd_broadcast))
    app.add_handler(CommandHandler("logs", admin.cmd_logs))
    app.add_handler(CommandHandler("restart", admin.cmd_restart))
    app.add_handler(CommandHandler("update", admin.cmd_update))

    # ===== لوحة الإدارة الجديدة =====
    app.add_handler(CommandHandler("admin", admin_dashboard.cmd_admin))
    app.add_handler(
        CallbackQueryHandler(admin_dashboard.on_admin_callback, pattern="^admin_")
    )

    # ===== الجودة الافتراضية =====
    app.add_handler(CallbackQueryHandler(menu.on_quality_callback, pattern="^setq_"))

    # ===== إدارة الكوكيز (أدمن) =====
    app.add_handler(CommandHandler("check_cookies", cookies.cmd_check_cookies))
    app.add_handler(CommandHandler("update_cookies", cookies.cmd_update_cookies))
    app.add_handler(
        CallbackQueryHandler(cookies.on_cookie_site_callback, pattern="^cksite_")
    )
    app.add_handler(MessageHandler(filters.Document.ALL, cookies.on_cookie_document))

    # ===== حالة البوت (أونر فقط) =====
    app.add_handler(CommandHandler("status", status.cmd_status))

    # ===== معالج نصوص موحّد =====
    async def on_text_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
        # 1. ضغطة على زر من القائمة الثابتة؟
        if await menu.is_menu_button(update):
            await menu.handle_menu_button(update, context)
            return

        # 2. الأدمن وسط عملية (برودكاست/حظر)؟
        pending_action = context.user_data.get("admin_action")
        if pending_action and await admin_dashboard.is_admin_check(update):
            await admin_dashboard.on_admin_text_input(update, context)
            return

        # 3. التحقق من Force Subscribe
        if not await force_subscribe.check_subscription(update, context):
            await force_subscribe.send_subscribe_message(update, context)
            return

        # 4. معالجة كرابط فيديو عادي
        await download.on_message(update, context)

    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, on_text_message))
    app.add_handler(CallbackQueryHandler(download.on_download_callback, pattern="^dl"))

    # ===== معالجة الأخطاء =====
    app.add_error_handler(on_error)

    logger.info("✅ البوت شغال دلوقتي...")
    app.run_polling(allowed_updates=Update.ALL_TYPES)


if __name__ == "__main__":
    main()

ZEOF_MARKER_UNIQUE
echo "✅ تم تحديث bot.py"

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
from utils.logger import logger, get_download_logger
from utils.i18n import t
from utils.validators import is_valid_url, detect_site, extract_first_url
from utils.helpers import rate_limiter, download_rate_limiter, format_duration
from services.downloader import (
    get_video_info,
    get_quality_estimates,
    download_video,
    cleanup_file,
)
from services.audio import download_audio
from services.thumbnail import download_thumbnail
from utils.download_tracker import download_slot
from handlers.menu import get_default_quality

download_logger = get_download_logger()

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

    # حد التحميلات لكل مستخدم (منفصل عن حد الرسائل العام)
    if not download_rate_limiter.is_allowed(user_id):
        await query.edit_message_text(
            "⏳ <b>كثرت عليها شوية!</b>\n\nوصلت للحد المسموح من التحميلات، استنى دقيقة وحاول تاني.",
            parse_mode="HTML",
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
        async with download_slot():
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
                    await context.bot.send_photo(
                        chat_id=query.message.chat_id,
                        photo=f,
                        read_timeout=120,
                        write_timeout=120,
                        connect_timeout=60,
                    )
                format_name = "Thumbnail"
            else:
                format_name = action

        site = detect_site(url)
        await db.log_download(user_id, url, site, format_name, "success")
        download_logger.info(f"نجح | user={user_id} | site={site} | format={format_name} | url={url}")
        _pending_urls.pop(short_id, None)

    except Exception as e:
        logger.error(f"فشل تنفيذ التحميل للرابط {url}: {e}")
        site = detect_site(url)
        download_logger.error(f"فشل | user={user_id} | site={site} | action={action} | url={url} | error={e}")
        await context.bot.send_message(
            chat_id=query.message.chat_id,
            text="❌ <b>حصل خطأ أثناء التحميل</b>\n\nحاول تاني أو جرب رابط مختلف.",
            parse_mode="HTML",
        )
        await db.log_download(user_id, url, site, action, "failed")

    finally:
        if file_path:
            cleanup_file(file_path)


async def _send_with_size_check(query, context, file_path: str, is_video: bool):
    import os

    size_mb = os.path.getsize(file_path) / (1024 * 1024)
    if size_mb > config.MAX_FILE_SIZE_MB:
        download_logger.warning(
            f"مرفوض (حجم كبير) | user={query.from_user.id} | size={size_mb:.0f}MB "
            f"| limit={config.MAX_FILE_SIZE_MB}MB | file={file_path}"
        )
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
            await context.bot.send_video(
                chat_id=query.message.chat_id,
                video=f,
                supports_streaming=True,
                read_timeout=300,
                write_timeout=300,
                connect_timeout=60,
            )
        else:
            await context.bot.send_audio(
                chat_id=query.message.chat_id,
                audio=f,
                read_timeout=300,
                write_timeout=300,
                connect_timeout=60,
            )

ZEOF_MARKER_UNIQUE
echo "✅ تم تحديث handlers/download.py"

echo "🔍 فحص الأكواد..."
python -m py_compile bot.py handlers/download.py
echo ""
echo "✅✅✅ تم بنجاح! ✅✅✅"
echo ""
echo "الخطوة الجاية:"
echo "  git add ."
echo "  git commit -m 'Increase upload timeout for large video files'"
echo "  git push"
echo "  bash run.sh"