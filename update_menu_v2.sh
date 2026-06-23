#!/data/data/com.termux/files/usr/bin/bash
# update_menu_v2.sh
set -e
echo "🔧 بدء تطبيق ميزات القائمة الموسعة..."

mkdir -p $(dirname 'handlers/menu.py')
cat > 'handlers/menu.py' << 'ZEOF_MARKER_UNIQUE'
"""
handlers/menu.py
قائمة أزرار ثابتة (Reply Keyboard) موسّعة بميزات إضافية:
- تحميلاتي الأخيرة
- الجودة الافتراضية
- معلوماتي
- تواصل مع الدعم
- لوحة التحكم (للأدمن فقط)
"""

import time
from datetime import datetime
from telegram import (
    Update,
    ReplyKeyboardMarkup,
    KeyboardButton,
    InlineKeyboardButton,
    InlineKeyboardMarkup,
)
from telegram.ext import ContextTypes

from config import config
from database.models import db
from utils.helpers import format_size


# ===================== بناء القائمة =====================

def build_main_menu(lang: str = "ar", is_admin: bool = False) -> ReplyKeyboardMarkup:
    """بناء القائمة الرئيسية الثابتة"""
    if lang == "en":
        buttons = [
            [KeyboardButton("📥 Download"), KeyboardButton("ℹ️ Help")],
            [KeyboardButton("⚙️ Settings"), KeyboardButton("📊 My Stats")],
            [KeyboardButton("📜 Recent Downloads"), KeyboardButton("🎚️ Default Quality")],
            [KeyboardButton("🆔 My Info"), KeyboardButton("📞 Contact Support")],
            [KeyboardButton("🌐 Language"), KeyboardButton("🏓 Ping")],
        ]
        if is_admin:
            buttons.append([KeyboardButton("🛠️ Admin Panel")])
    else:
        buttons = [
            [KeyboardButton("📥 تحميل فيديو"), KeyboardButton("ℹ️ المساعدة")],
            [KeyboardButton("⚙️ الإعدادات"), KeyboardButton("📊 إحصائياتي")],
            [KeyboardButton("📜 تحميلاتي الأخيرة"), KeyboardButton("🎚️ الجودة الافتراضية")],
            [KeyboardButton("🆔 معلوماتي"), KeyboardButton("📞 تواصل مع الدعم")],
            [KeyboardButton("🌐 اللغة"), KeyboardButton("🏓 فحص السرعة")],
        ]
        if is_admin:
            buttons.append([KeyboardButton("🛠️ لوحة التحكم")])

    return ReplyKeyboardMarkup(buttons, resize_keyboard=True, is_persistent=True)


async def get_lang(user_id: int) -> str:
    return await db.get_user_language(user_id)


# ===================== ربط نص الزر بالعملية =====================

BUTTON_TEXTS_AR = {
    "📥 تحميل فيديو": "download_info",
    "ℹ️ المساعدة": "help",
    "⚙️ الإعدادات": "settings",
    "📊 إحصائياتي": "stats",
    "📜 تحميلاتي الأخيرة": "recent_downloads",
    "🎚️ الجودة الافتراضية": "default_quality",
    "🆔 معلوماتي": "my_info",
    "📞 تواصل مع الدعم": "contact_support",
    "🌐 اللغة": "lang",
    "🏓 فحص السرعة": "ping",
    "🛠️ لوحة التحكم": "admin_panel",
}

BUTTON_TEXTS_EN = {
    "📥 Download": "download_info",
    "ℹ️ Help": "help",
    "⚙️ Settings": "settings",
    "📊 My Stats": "stats",
    "📜 Recent Downloads": "recent_downloads",
    "🎚️ Default Quality": "default_quality",
    "🆔 My Info": "my_info",
    "📞 Contact Support": "contact_support",
    "🌐 Language": "lang",
    "🏓 Ping": "ping",
    "🛠️ Admin Panel": "admin_panel",
}

ALL_BUTTON_TEXTS = set(BUTTON_TEXTS_AR.keys()) | set(BUTTON_TEXTS_EN.keys())


def get_button_action(text: str):
    return BUTTON_TEXTS_AR.get(text) or BUTTON_TEXTS_EN.get(text)


async def is_menu_button(update: Update) -> bool:
    text = update.message.text if update.message else None
    return text in ALL_BUTTON_TEXTS if text else False


# ===================== جودة افتراضية: تخزين/قراءة =====================

async def get_default_quality(user_id: int) -> str:
    """جلب الجودة الافتراضية المحفوظة للمستخدم، أو 'غير محدد'"""
    value = await db.get_setting(f"quality_{user_id}", default="")
    return value or ""


async def set_default_quality(user_id: int, height: str):
    await db.set_setting(f"quality_{user_id}", height)


# ===================== توجيه ضغطة الزر =====================

async def handle_menu_button(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """توجيه ضغطة الزر للعملية المناسبة"""
    from handlers import help as help_handler, settings, start, admin_dashboard

    text = update.message.text
    action = get_button_action(text)
    user_id = update.effective_user.id
    lang = await get_lang(user_id)

    if action == "help":
        await help_handler.cmd_help(update, context)

    elif action == "settings":
        await settings.cmd_settings(update, context)

    elif action == "stats":
        await settings.cmd_stats(update, context)

    elif action == "lang":
        await start.cmd_lang(update, context)

    elif action == "ping":
        await start.cmd_ping(update, context)

    elif action == "download_info":
        if lang == "en":
            await update.message.reply_text(
                "📥 Just send me any video link (YouTube, TikTok, Facebook, "
                "Instagram, X/Twitter, etc.) and I'll show you download options!"
            )
        else:
            await update.message.reply_text(
                "📥 بس ابعتلي رابط أي فيديو (يوتيوب، تيك توك، فيسبوك، انستجرام، "
                "تويتر/X، وغيرهم) وهتلاقي خيارات التحميل تظهرلك على طول!"
            )

    elif action == "recent_downloads":
        await _show_recent_downloads(update, lang, user_id)

    elif action == "default_quality":
        await _show_quality_picker(update, lang)

    elif action == "my_info":
        await _show_my_info(update, lang, user_id)

    elif action == "contact_support":
        context.user_data["support_action"] = True
        if lang == "en":
            await update.message.reply_text(
                "📞 Write your message and it will be sent directly to the admin.\n"
                "Send /cancel to cancel."
            )
        else:
            await update.message.reply_text(
                "📞 اكتب رسالتك وهتتبعت مباشرة للأدمن.\n"
                "ابعت /cancel للإلغاء."
            )

    elif action == "admin_panel":
        if await db.is_admin(user_id):
            await admin_dashboard.cmd_admin(update, context)
        else:
            await update.message.reply_text("🚫 هذه الميزة للأدمن فقط.")


# ===================== دوال مساعدة =====================

async def _show_recent_downloads(update: Update, lang: str, user_id: int):
    rows = await db.get_recent_downloads(user_id, limit=5)

    if not rows:
        text = (
            "📜 لسه مفيش تحميلات سابقة." if lang == "ar"
            else "📜 No previous downloads yet."
        )
        await update.message.reply_text(text)
        return

    lines = ["📜 آخر تحميلاتك:\n"] if lang == "ar" else ["📜 Your recent downloads:\n"]
    for url, site, fmt, created_at in rows:
        date_str = datetime.fromtimestamp(created_at).strftime("%Y-%m-%d %H:%M")
        short_url = url if len(url) <= 45 else url[:42] + "..."
        lines.append(f"🔗 {short_url}\n📌 {site} | {fmt} | 🕒 {date_str}\n")

    await update.message.reply_text("\n".join(lines))


async def _show_quality_picker(update: Update, lang: str):
    current = await get_default_quality(update.effective_user.id)
    current_label = f"{current}p" if current else ("غير محدد" if lang == "ar" else "Not set")

    text = (
        f"🎚️ جودتك الافتراضية الحالية: <b>{current_label}</b>\n\nاختار جودة جديدة:"
        if lang == "ar" else
        f"🎚️ Current default quality: <b>{current_label}</b>\n\nPick a new one:"
    )

    keyboard = InlineKeyboardMarkup(
        [
            [InlineKeyboardButton("🎥 2160p (4K)", callback_data="setq_2160")],
            [InlineKeyboardButton("🎬 1080p (Full HD)", callback_data="setq_1080")],
            [InlineKeyboardButton("📱 720p (HD)", callback_data="setq_720")],
            [InlineKeyboardButton("📞 480p (Mobile)", callback_data="setq_480")],
            [InlineKeyboardButton("❌ بدون (اختار كل مرة)" if lang == "ar" else "❌ None (ask every time)", callback_data="setq_none")],
        ]
    )
    await update.message.reply_text(text, parse_mode="HTML", reply_markup=keyboard)


async def on_quality_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """معالجة اختيار الجودة الافتراضية من القائمة"""
    query = update.callback_query
    await query.answer()

    user_id = query.from_user.id
    lang = await get_lang(user_id)
    value = query.data.replace("setq_", "")

    if value == "none":
        await set_default_quality(user_id, "")
        msg = "✅ تم إلغاء الجودة الافتراضية. هتختار في كل مرة." if lang == "ar" else "✅ Default quality cleared."
    else:
        await set_default_quality(user_id, value)
        msg = f"✅ تم حفظ {value}p كجودة افتراضية لك." if lang == "ar" else f"✅ Saved {value}p as your default quality."

    await query.edit_message_text(msg)


async def _show_my_info(update: Update, lang: str, user_id: int):
    row = await db.get_user(user_id)
    downloads_count = await db.count_user_downloads(user_id)
    default_q = await get_default_quality(user_id)

    username = f"@{row[1]}" if row and row[1] else "—"
    joined_ts = row[4] if row else None
    joined_str = (
        datetime.fromtimestamp(joined_ts).strftime("%Y-%m-%d")
        if joined_ts else "—"
    )
    quality_label = f"{default_q}p" if default_q else ("غير محددة" if lang == "ar" else "Not set")

    if lang == "en":
        text = (
            f"🆔 <b>My Info</b>\n\n"
            f"User ID: <code>{user_id}</code>\n"
            f"Username: {username}\n"
            f"Joined: {joined_str}\n"
            f"Total downloads: {downloads_count}\n"
            f"Default quality: {quality_label}"
        )
    else:
        text = (
            f"🆔 <b>معلوماتي</b>\n\n"
            f"آيدي تليجرام: <code>{user_id}</code>\n"
            f"اسم المستخدم: {username}\n"
            f"تاريخ الانضمام: {joined_str}\n"
            f"عدد التحميلات الكلي: {downloads_count}\n"
            f"الجودة الافتراضية: {quality_label}"
        )

    await update.message.reply_text(text, parse_mode="HTML")

ZEOF_MARKER_UNIQUE
echo "✅ تم تحديث handlers/menu.py"

mkdir -p $(dirname 'handlers/start.py')
cat > 'handlers/start.py' << 'ZEOF_MARKER_UNIQUE'
"""
handlers/start.py
أوامر البداية والمعلومات العامة: /start /about /ping /lang
"""

import time
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import ContextTypes

from config import config
from database.models import db
from utils.i18n import t
from handlers.menu import build_main_menu


async def get_lang(user_id: int) -> str:
    return await db.get_user_language(user_id)


async def ensure_user(update: Update):
    user = update.effective_user
    await db.add_or_update_user(user.id, user.username or "", user.first_name or "")


async def check_banned(update: Update) -> bool:
    user_id = update.effective_user.id
    if await db.is_banned(user_id):
        lang = await get_lang(user_id)
        await update.message.reply_text(t("banned", lang))
        return True
    return False


async def cmd_start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    await ensure_user(update)
    if await check_banned(update):
        return
    lang = await get_lang(update.effective_user.id)
    name = update.effective_user.first_name or ""
    is_admin = await db.is_admin(update.effective_user.id)
    await update.message.reply_text(
        t("start", lang, name=name), reply_markup=build_main_menu(lang, is_admin)
    )


async def cmd_about(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if await check_banned(update):
        return
    lang = await get_lang(update.effective_user.id)
    sites = "، ".join(config.SUPPORTED_SITES)
    await update.message.reply_text(t("about", lang, sites=sites))


async def cmd_ping(update: Update, context: ContextTypes.DEFAULT_TYPE):
    start = time.monotonic()
    lang = await get_lang(update.effective_user.id)
    msg = await update.message.reply_text("🏓 ...")
    elapsed_ms = int((time.monotonic() - start) * 1000)
    await msg.edit_text(t("ping", lang, ms=elapsed_ms))


async def cmd_lang(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if await check_banned(update):
        return
    lang = await get_lang(update.effective_user.id)
    keyboard = InlineKeyboardMarkup(
        [
            [
                InlineKeyboardButton("🇪🇬 العربية", callback_data="setlang_ar"),
                InlineKeyboardButton("🇬🇧 English", callback_data="setlang_en"),
            ]
        ]
    )
    await update.message.reply_text(t("lang_choose", lang), reply_markup=keyboard)


async def on_lang_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    new_lang = query.data.replace("setlang_", "")
    await db.set_user_language(query.from_user.id, new_lang)
    await query.edit_message_text(t("lang_changed", new_lang))
    is_admin = await db.is_admin(query.from_user.id)
    await context.bot.send_message(
        chat_id=query.message.chat_id,
        text="🔄",
        reply_markup=build_main_menu(new_lang, is_admin),
    )

ZEOF_MARKER_UNIQUE
echo "✅ تم تحديث handlers/start.py"

mkdir -p $(dirname 'bot.py')
cat > 'bot.py' << 'ZEOF_MARKER_UNIQUE'
"""
bot.py - النسخة 2.3
- لوحة إدارة كاملة
- اختيار جودة دقيقة + جودة افتراضية
- Force Subscribe
- شريط تقدم
- قائمة أزرار ثابتة موسّعة (تحميلاتي الأخيرة، معلوماتي، تواصل مع الدعم، لوحة تحكم)
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
from handlers import admin_dashboard, force_subscribe, menu


async def on_error(update: object, context: ContextTypes.DEFAULT_TYPE):
    logger.error(f"حدث خطأ غير متوقع: {context.error}", exc_info=context.error)


async def post_init(application: Application):
    await db.connect()
    logger.info("✅ تم الاتصال بقاعدة البيانات بنجاح")


async def post_shutdown(application: Application):
    await db.close()
    logger.info("🔌 تم إغلاق الاتصال بقاعدة البيانات")


async def cmd_cancel(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """إلغاء أي عملية معلّقة (دعم/برودكاست/حظر)"""
    context.user_data.pop("support_action", None)
    context.user_data.pop("admin_action", None)
    await update.message.reply_text("✅ تم الإلغاء.")


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

    # ===== معالج نصوص موحّد =====
    async def on_text_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
        # 1. المستخدم وسط كتابة رسالة دعم؟
        if context.user_data.get("support_action"):
            await _forward_support_message(update, context)
            return

        # 2. ضغطة على زر من القائمة الثابتة؟
        if await menu.is_menu_button(update):
            await menu.handle_menu_button(update, context)
            return

        # 3. الأدمن وسط عملية (برودكاست/حظر)؟
        pending_action = context.user_data.get("admin_action")
        if pending_action and await admin_dashboard.is_admin_check(update):
            await admin_dashboard.on_admin_text_input(update, context)
            return

        # 4. التحقق من Force Subscribe
        if not await force_subscribe.check_subscription(update, context):
            await force_subscribe.send_subscribe_message(update, context)
            return

        # 5. معالجة كرابط فيديو عادي
        await download.on_message(update, context)

    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, on_text_message))
    app.add_handler(CallbackQueryHandler(download.on_download_callback, pattern="^dl"))

    # ===== معالجة الأخطاء =====
    app.add_error_handler(on_error)

    logger.info("✅ البوت شغال دلوقتي...")
    app.run_polling(allowed_updates=Update.ALL_TYPES)


async def _forward_support_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """تحويل رسالة الدعم من المستخدم للأونر مباشرة"""
    context.user_data.pop("support_action", None)
    user = update.effective_user
    text = update.message.text

    try:
        await context.bot.send_message(
            chat_id=config.OWNER_ID,
            text=(
                f"📞 رسالة دعم جديدة\n\n"
                f"من: {user.first_name or ''} (@{user.username or '—'})\n"
                f"آيدي: {user.id}\n\n"
                f"الرسالة:\n{text}"
            ),
        )
        await update.message.reply_text("✅ تم إرسال رسالتك للدعم، هيتم الرد عليك قريبًا.")
    except Exception as e:
        logger.error(f"فشل تحويل رسالة الدعم: {e}")
        await update.message.reply_text("❌ حصل خطأ أثناء إرسال رسالتك، حاول تاني.")


if __name__ == "__main__":
    main()

ZEOF_MARKER_UNIQUE
echo "✅ تم تحديث bot.py"

mkdir -p $(dirname 'handlers/download.py')
cat > 'handlers/download.py' << 'ZEOF_MARKER_UNIQUE'
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

ZEOF_MARKER_UNIQUE
echo "✅ تم تحديث handlers/download.py"

mkdir -p $(dirname 'database/models.py')
cat > 'database/models.py' << 'ZEOF_MARKER_UNIQUE'
"""
database/models.py
كل العمليات على قاعدة بيانات SQLite (عبر aiosqlite) بشكل غير متزامن
"""

import aiosqlite
import time
from config import config


class Database:
    def __init__(self, path: str = None):
        self.path = path or config.DATABASE_PATH
        self._conn: aiosqlite.Connection | None = None

    async def connect(self):
        self._conn = await aiosqlite.connect(self.path)
        await self._conn.execute("PRAGMA journal_mode=WAL;")
        await self.create_tables()
        await self._migrate()

    async def _migrate(self):
        """إضافة أعمدة جديدة لو لسه مش موجودة (ميجريشن بسيط وآمن)"""
        try:
            await self._conn.execute(
                "ALTER TABLE users ADD COLUMN default_quality TEXT DEFAULT '1080'"
            )
            await self._conn.commit()
        except Exception:
            pass  # العمود موجود بالفعل

    async def close(self):
        if self._conn:
            await self._conn.close()

    async def create_tables(self):
        await self._conn.executescript(
            """
            CREATE TABLE IF NOT EXISTS users (
                user_id INTEGER PRIMARY KEY,
                username TEXT,
                first_name TEXT,
                language TEXT DEFAULT 'ar',
                joined_at INTEGER,
                last_active INTEGER
            );

            CREATE TABLE IF NOT EXISTS downloads (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER,
                url TEXT,
                site TEXT,
                format TEXT,
                status TEXT,
                created_at INTEGER
            );

            CREATE TABLE IF NOT EXISTS settings (
                key TEXT PRIMARY KEY,
                value TEXT
            );

            CREATE TABLE IF NOT EXISTS banned_users (
                user_id INTEGER PRIMARY KEY,
                reason TEXT,
                banned_at INTEGER
            );

            CREATE TABLE IF NOT EXISTS admins (
                user_id INTEGER PRIMARY KEY,
                added_at INTEGER
            );
            """
        )
        await self._conn.commit()

    # ===================== المستخدمين =====================

    async def add_or_update_user(self, user_id: int, username: str, first_name: str):
        now = int(time.time())
        await self._conn.execute(
            """
            INSERT INTO users (user_id, username, first_name, joined_at, last_active)
            VALUES (?, ?, ?, ?, ?)
            ON CONFLICT(user_id) DO UPDATE SET
                username = excluded.username,
                first_name = excluded.first_name,
                last_active = excluded.last_active
            """,
            (user_id, username, first_name, now, now),
        )
        await self._conn.commit()

    async def get_user(self, user_id: int):
        cursor = await self._conn.execute(
            "SELECT * FROM users WHERE user_id = ?", (user_id,)
        )
        return await cursor.fetchone()

    async def set_user_language(self, user_id: int, lang: str):
        await self._conn.execute(
            "UPDATE users SET language = ? WHERE user_id = ?", (lang, user_id)
        )
        await self._conn.commit()

    async def get_user_language(self, user_id: int) -> str:
        row = await self.get_user(user_id)
        if row and row[3]:
            return row[3]
        return config.DEFAULT_LANGUAGE

    async def count_users(self) -> int:
        cursor = await self._conn.execute("SELECT COUNT(*) FROM users")
        row = await cursor.fetchone()
        return row[0] if row else 0

    async def get_all_user_ids(self) -> list[int]:
        cursor = await self._conn.execute("SELECT user_id FROM users")
        rows = await cursor.fetchall()
        return [r[0] for r in rows]

    # ===================== التحميلات =====================

    async def log_download(self, user_id: int, url: str, site: str, fmt: str, status: str):
        await self._conn.execute(
            """
            INSERT INTO downloads (user_id, url, site, format, status, created_at)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            (user_id, url, site, fmt, status, int(time.time())),
        )
        await self._conn.commit()

    async def count_downloads(self) -> int:
        cursor = await self._conn.execute("SELECT COUNT(*) FROM downloads")
        row = await cursor.fetchone()
        return row[0] if row else 0

    async def count_user_downloads(self, user_id: int) -> int:
        cursor = await self._conn.execute(
            "SELECT COUNT(*) FROM downloads WHERE user_id = ?", (user_id,)
        )
        row = await cursor.fetchone()
        return row[0] if row else 0

    async def get_recent_downloads(self, user_id: int, limit: int = 5):
        """جلب آخر التحميلات الناجحة للمستخدم"""
        cursor = await self._conn.execute(
            """
            SELECT url, site, format, created_at FROM downloads
            WHERE user_id = ? AND status = 'success'
            ORDER BY created_at DESC LIMIT ?
            """,
            (user_id, limit),
        )
        return await cursor.fetchall()

    async def get_recent_downloads(self, user_id: int, limit: int = 5):
        """آخر تحميلات المستخدم (الأحدث أولًا)"""
        cursor = await self._conn.execute(
            """
            SELECT url, site, format, status, created_at
            FROM downloads
            WHERE user_id = ?
            ORDER BY id DESC
            LIMIT ?
            """,
            (user_id, limit),
        )
        return await cursor.fetchall()

    async def set_default_quality(self, user_id: int, quality: str):
        await self._conn.execute(
            "UPDATE users SET default_quality = ? WHERE user_id = ?",
            (quality, user_id),
        )
        await self._conn.commit()

    async def get_default_quality(self, user_id: int) -> str:
        cursor = await self._conn.execute(
            "SELECT default_quality FROM users WHERE user_id = ?", (user_id,)
        )
        row = await cursor.fetchone()
        return row[0] if row and row[0] else "1080"

    # ===================== الحظر =====================

    async def ban_user(self, user_id: int, reason: str = ""):
        await self._conn.execute(
            "INSERT OR REPLACE INTO banned_users (user_id, reason, banned_at) VALUES (?, ?, ?)",
            (user_id, reason, int(time.time())),
        )
        await self._conn.commit()

    async def unban_user(self, user_id: int):
        await self._conn.execute(
            "DELETE FROM banned_users WHERE user_id = ?", (user_id,)
        )
        await self._conn.commit()

    async def is_banned(self, user_id: int) -> bool:
        cursor = await self._conn.execute(
            "SELECT 1 FROM banned_users WHERE user_id = ?", (user_id,)
        )
        return await cursor.fetchone() is not None

    # ===================== الأدمنز =====================

    async def add_admin(self, user_id: int):
        await self._conn.execute(
            "INSERT OR IGNORE INTO admins (user_id, added_at) VALUES (?, ?)",
            (user_id, int(time.time())),
        )
        await self._conn.commit()

    async def remove_admin(self, user_id: int):
        await self._conn.execute("DELETE FROM admins WHERE user_id = ?", (user_id,))
        await self._conn.commit()

    async def get_admin_ids(self) -> list[int]:
        cursor = await self._conn.execute("SELECT user_id FROM admins")
        rows = await cursor.fetchall()
        return [r[0] for r in rows] + config.ADMIN_IDS + [config.OWNER_ID]

    async def is_admin(self, user_id: int) -> bool:
        if user_id == config.OWNER_ID or user_id in config.ADMIN_IDS:
            return True
        cursor = await self._conn.execute(
            "SELECT 1 FROM admins WHERE user_id = ?", (user_id,)
        )
        return await cursor.fetchone() is not None

    # ===================== الإعدادات =====================

    async def get_setting(self, key: str, default=None):
        cursor = await self._conn.execute(
            "SELECT value FROM settings WHERE key = ?", (key,)
        )
        row = await cursor.fetchone()
        return row[0] if row else default

    async def set_setting(self, key: str, value: str):
        await self._conn.execute(
            "INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)",
            (key, value),
        )
        await self._conn.commit()


# نسخة واحدة مشتركة تُستخدم في كل المشروع
db = Database()

ZEOF_MARKER_UNIQUE
echo "✅ تم تحديث database/models.py"

mkdir -p $(dirname 'handlers/settings.py')
cat > 'handlers/settings.py' << 'ZEOF_MARKER_UNIQUE'
"""
handlers/settings.py
أوامر /settings و /stats الخاصة بالمستخدم
"""

from telegram import Update
from telegram.ext import ContextTypes

from database.models import db
from utils.i18n import t


async def cmd_settings(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_id = update.effective_user.id
    if await db.is_banned(user_id):
        lang = await db.get_user_language(user_id)
        await update.message.reply_text(t("banned", lang))
        return
    lang = await db.get_user_language(user_id)
    await update.message.reply_text(t("settings", lang, current_lang=lang))


async def cmd_stats(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_id = update.effective_user.id
    if await db.is_banned(user_id):
        lang = await db.get_user_language(user_id)
        await update.message.reply_text(t("banned", lang))
        return
    lang = await db.get_user_language(user_id)
    downloads_count = await db.count_user_downloads(user_id)
    await update.message.reply_text(t("stats_user", lang, downloads=downloads_count))

ZEOF_MARKER_UNIQUE
echo "✅ تم تحديث handlers/settings.py"

mkdir -p $(dirname 'languages/ar.json')
cat > 'languages/ar.json' << 'ZEOF_MARKER_UNIQUE'
{
  "start": "👋 أهلاً بيك يا {name}!\n\nأنا بوت تحميل فيديوهات من السوشيال ميديا (يوتيوب، تيك توك، فيسبوك، انستجرام، تويتر/X، وغيرهم).\n\n📥 بس ابعتلي رابط الفيديو وهتلاقي خيارات التحميل تظهرلك.\n\nاكتب /help لمعرفة كل الأوامر.",
  "help": "📖 قائمة الأوامر:\n\n/start - بدء استخدام البوت\n/help - عرض هذه القائمة\n/about - معلومات عن البوت\n/settings - الإعدادات\n/stats - إحصائياتك\n/lang - تغيير اللغة\n/ping - فحص سرعة استجابة البوت\n\n📥 لتحميل فيديو: ابعت الرابط مباشرة في الشات.",
  "about": "ℹ️ بوت تحميل فيديوهات احترافي\n\nيدعم: {sites}\n\nمبني بـ Python + yt-dlp + python-telegram-bot",
  "ping": "🏓 Pong!\nزمن الاستجابة: {ms} ms",
  "settings": "⚙️ الإعدادات\n\nاللغة الحالية: {current_lang}\nلتغيير اللغة استخدم /lang",
  "stats_user": "📊 إحصائياتك:\n\nعدد التحميلات: {downloads}",
  "lang_choose": "🌐 اختر لغتك:",
  "lang_changed": "✅ تم تغيير اللغة إلى العربية",
  "banned": "🚫 تم حظرك من استخدام هذا البوت.",
  "rate_limited": "⏳ كثرت عليها شوية! استنى لحظات وحاول تاني.",
  "invalid_url": "❌ الرابط ده غير صحيح أو الموقع غير مدعوم.",
  "analyzing": "🔍 بحلل الرابط... لحظات.",
  "coming_soon": "🚧 ميزة التحميل قيد التطوير حاليًا وهتتفعل في المرحلة الجاية من المشروع."
}

ZEOF_MARKER_UNIQUE
echo "✅ تم تحديث languages/ar.json"

mkdir -p $(dirname 'languages/en.json')
cat > 'languages/en.json' << 'ZEOF_MARKER_UNIQUE'
{
  "start": "👋 Hello {name}!\n\nI'm a social media video downloader bot (YouTube, TikTok, Facebook, Instagram, X/Twitter, and more).\n\n📥 Just send me a video link and download options will appear.\n\nType /help to see all commands.",
  "help": "📖 Commands list:\n\n/start - Start the bot\n/help - Show this menu\n/about - About this bot\n/settings - Settings\n/stats - Your stats\n/lang - Change language\n/ping - Check bot response time\n\n📥 To download a video: just send the link in chat.",
  "about": "ℹ️ Professional video downloader bot\n\nSupports: {sites}\n\nBuilt with Python + yt-dlp + python-telegram-bot",
  "ping": "🏓 Pong!\nResponse time: {ms} ms",
  "settings": "⚙️ Settings\n\nCurrent language: {current_lang}\nTo change language use /lang",
  "stats_user": "📊 Your stats:\n\nDownloads: {downloads}",
  "lang_choose": "🌐 Choose your language:",
  "lang_changed": "✅ Language changed to English",
  "banned": "🚫 You are banned from using this bot.",
  "rate_limited": "⏳ Slow down! Please wait a moment and try again.",
  "invalid_url": "❌ This link is invalid or the site is not supported.",
  "analyzing": "🔍 Analyzing the link... please wait.",
  "coming_soon": "🚧 Download feature is under development and will be enabled in the next project phase."
}

ZEOF_MARKER_UNIQUE
echo "✅ تم تحديث languages/en.json"

echo "🔍 فحص الأكواد..."
python -m py_compile bot.py handlers/*.py database/*.py
echo ""
echo "✅✅✅ تم تطبيق كل الميزات بنجاح! ✅✅✅"
echo ""
echo "الخطوة الجاية:"
echo "  git add ."
echo "  git commit -m 'Add extended menu features'"
echo "  git push"
echo "  python bot.py"