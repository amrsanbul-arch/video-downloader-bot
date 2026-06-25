#!/data/data/com.termux/files/usr/bin/bash
# direct_chat_button.sh
set -e
echo "🔧 تطبيق زرار التواصل المباشر مع المطور..."

cat > 'config.py' << 'ZEOF_MARKER_UNIQUE'
"""
config.py
ملف الإعدادات الرئيسي للبوت - يقرأ المتغيرات من .env
"""

import os
from dotenv import load_dotenv

# تحميل متغيرات البيئة من ملف .env
load_dotenv()


class Config:
    # ===== التوكن والمالك =====
    BOT_TOKEN: str = os.getenv("BOT_TOKEN", "")
    OWNER_ID: int = int(os.getenv("OWNER_ID", "0"))

    # تحويل قائمة الأدمنز من نص إلى أرقام
    _admin_raw = os.getenv("ADMIN_IDS", "")
    ADMIN_IDS: list[int] = [
        int(x.strip()) for x in _admin_raw.split(",") if x.strip().isdigit()
    ]

    # ===== التحميل =====
    MAX_FILE_SIZE_MB: int = int(os.getenv("MAX_FILE_SIZE_MB", "2000"))
    DOWNLOAD_DIR: str = os.getenv("DOWNLOAD_DIR", "downloads")
    DOWNLOAD_TIMEOUT: int = int(os.getenv("DOWNLOAD_TIMEOUT", "300"))

    # ===== قاعدة البيانات =====
    DATABASE_PATH: str = os.getenv("DATABASE_PATH", "database/bot.db")

    # ===== Cookies (لمواقع تطلب تسجيل دخول مثل Reddit/Instagram/TikTok أحيانًا) =====
    COOKIES_FILE: str = os.getenv("COOKIES_FILE", "")

    # ===== Force Subscribe (اختياري) =====
    # ضع اسم القناة بدون @ (مثل: channel_name)
    FORCE_SUBSCRIBE_CHANNEL: str = os.getenv("FORCE_SUBSCRIBE_CHANNEL", "")

    # ===== اسم البوت (يظهر في رسائل "تواصل مع المطور" لتمييزه لو عندك أكتر من بوت) =====
    BOT_DISPLAY_NAME: str = os.getenv("BOT_DISPLAY_NAME", "بوت تحميل الفيديوهات")

    # ===== يوزر المطور على تليجرام (بدون @) =====
    # زرار "تواصل مع المطور" هيفتح شات مباشر مع هذا اليوزر
    OWNER_USERNAME: str = os.getenv("OWNER_USERNAME", "")

    # ===== اللغة =====
    DEFAULT_LANGUAGE: str = os.getenv("DEFAULT_LANGUAGE", "ar")

    # ===== Rate Limit =====
    RATE_LIMIT_MESSAGES: int = int(os.getenv("RATE_LIMIT_MESSAGES", "5"))
    RATE_LIMIT_SECONDS: int = int(os.getenv("RATE_LIMIT_SECONDS", "10"))

    # ===== المواقع المدعومة (لعرضها في /help و /about) =====
    SUPPORTED_SITES = [
        "YouTube", "TikTok", "Facebook", "Instagram", "X (Twitter)",
        "Snapchat", "Reddit", "Pinterest", "Vimeo", "Dailymotion",
    ]

    @classmethod
    def validate(cls):
        """التحقق من وجود الإعدادات الأساسية قبل تشغيل البوت"""
        errors = []
        if not cls.BOT_TOKEN:
            errors.append("BOT_TOKEN غير موجود في ملف .env")
        if cls.OWNER_ID == 0:
            errors.append("OWNER_ID غير موجود أو غير صحيح في ملف .env")

        if errors:
            raise ValueError(
                "❌ أخطاء في الإعدادات:\n" + "\n".join(f"- {e}" for e in errors)
            )

        # التأكد من وجود المجلدات المطلوبة
        os.makedirs(cls.DOWNLOAD_DIR, exist_ok=True)
        os.makedirs("logs", exist_ok=True)
        os.makedirs(os.path.dirname(cls.DATABASE_PATH) or ".", exist_ok=True)

        # تحذير (وليس خطأ يوقف البوت) لو ملف الكوكيز محدد بس غير موجود فعليًا
        if cls.COOKIES_FILE and not os.path.exists(cls.COOKIES_FILE):
            print(
                f"⚠️ تحذير: ملف الكوكيز '{cls.COOKIES_FILE}' محدد في .env "
                f"لكنه غير موجود في المسار. التحميل من مواقع تتطلب تسجيل دخول سيفشل."
            )


config = Config()

ZEOF_MARKER_UNIQUE
echo "✅ تم تحديث config.py"

cat > '.env.example' << 'ZEOF_MARKER_UNIQUE'
# ===== إعدادات البوت الأساسية =====
BOT_TOKEN=ضع_التوكن_هنا

# آي دي الأونر (المالك) - رقم تليجرام بتاعك
OWNER_ID=123456789

# آي ديز المشرفين، مفصولة بفاصلة (اختياري)
ADMIN_IDS=

# ===== إعدادات التحميل =====
MAX_FILE_SIZE_MB=2000
DOWNLOAD_DIR=downloads
DOWNLOAD_TIMEOUT=300

# ===== إعدادات قاعدة البيانات =====
DATABASE_PATH=database/bot.db

# مسار ملف الكوكيز (اختياري) - مطلوب لبعض المواقع اللي بقت تطلب تسجيل دخول
# مثل Reddit وبعض فيديوهات انستجرام/تيك توك الخاصة
# اتركه فاضي لو مش محتاجه
COOKIES_FILE=

# ===== Force Subscribe (اختياري) =====
# اسم القناة بدون @ لو تبي تفرض اشتراك على المستخدمين قبل التحميل
# مثل: my_channel أو اتركه فاضي للتعطيل
FORCE_SUBSCRIBE_CHANNEL=

# اسم البوت يظهر في رسائل "تواصل مع المطور" (مفيد لو شغال عدة بوتات بنفس حساب المطور)
BOT_DISPLAY_NAME=بوت تحميل الفيديوهات

# يوزرك على تليجرام بدون @ (مثل: amrsanbul)
# زرار "تواصل مع المطور" هيفتح شات مباشر معاك بدالة هذا اليوزر
OWNER_USERNAME=

# ===== إعدادات اللغة =====
DEFAULT_LANGUAGE=ar

# ===== Rate Limit =====
RATE_LIMIT_MESSAGES=5
RATE_LIMIT_SECONDS=10

ZEOF_MARKER_UNIQUE
echo "✅ تم تحديث .env.example"

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
        .read_timeout(30)
        .write_timeout(30)
        .pool_timeout(30)
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
    """بناء القائمة الرئيسية الثابتة (بدون إيموجي، الزرار الرئيسي في صف لوحده)"""
    if lang == "en":
        buttons = [
            [KeyboardButton("Download Video")],
            [KeyboardButton("Help"), KeyboardButton("Settings"), KeyboardButton("My Stats")],
            [KeyboardButton("Recent Downloads"), KeyboardButton("Default Quality"), KeyboardButton("My Info")],
            [KeyboardButton("Contact Developer"), KeyboardButton("Language"), KeyboardButton("Ping")],
        ]
        if is_admin:
            buttons.append([KeyboardButton("Admin Panel")])
    else:
        buttons = [
            [KeyboardButton("تحميل فيديو")],
            [KeyboardButton("المساعدة"), KeyboardButton("الإعدادات"), KeyboardButton("إحصائياتي")],
            [KeyboardButton("تحميلاتي الأخيرة"), KeyboardButton("الجودة الافتراضية"), KeyboardButton("معلوماتي")],
            [KeyboardButton("تواصل مع المطور"), KeyboardButton("اللغة"), KeyboardButton("فحص السرعة")],
        ]
        if is_admin:
            buttons.append([KeyboardButton("لوحة التحكم")])

    return ReplyKeyboardMarkup(buttons, resize_keyboard=True, is_persistent=True)


async def get_lang(user_id: int) -> str:
    return await db.get_user_language(user_id)


# ===================== ربط نص الزر بالعملية =====================

BUTTON_TEXTS_AR = {
    "تحميل فيديو": "download_info",
    "المساعدة": "help",
    "الإعدادات": "settings",
    "إحصائياتي": "stats",
    "تحميلاتي الأخيرة": "recent_downloads",
    "الجودة الافتراضية": "default_quality",
    "معلوماتي": "my_info",
    "تواصل مع المطور": "contact_support",
    "اللغة": "lang",
    "فحص السرعة": "ping",
    "لوحة التحكم": "admin_panel",
}

BUTTON_TEXTS_EN = {
    "Download Video": "download_info",
    "Help": "help",
    "Settings": "settings",
    "My Stats": "stats",
    "Recent Downloads": "recent_downloads",
    "Default Quality": "default_quality",
    "My Info": "my_info",
    "Contact Developer": "contact_support",
    "Language": "lang",
    "Ping": "ping",
    "Admin Panel": "admin_panel",
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
                "📥 <b>How to download</b>\n\n"
                "• Just send me any video link\n"
                "• YouTube, TikTok, Facebook, Instagram, X/Twitter, etc.\n"
                "• Download options will appear automatically",
                parse_mode="HTML",
            )
        else:
            await update.message.reply_text(
                "📥 <b>طريقة التحميل</b>\n\n"
                "• بس ابعتلي رابط أي فيديو\n"
                "• يوتيوب، تيك توك، فيسبوك، انستجرام، تويتر/X، وغيرهم\n"
                "• خيارات التحميل هتظهرلك تلقائيًا",
                parse_mode="HTML",
            )

    elif action == "recent_downloads":
        await _show_recent_downloads(update, lang, user_id)

    elif action == "default_quality":
        await _show_quality_picker(update, lang)

    elif action == "my_info":
        await _show_my_info(update, lang, user_id)

    elif action == "contact_support":
        username = getattr(config, "OWNER_USERNAME", "")
        if not username:
            text = (
                "لم يتم تحديد حساب المطور بعد." if lang == "ar"
                else "Developer account not set yet."
            )
            await update.message.reply_text(text)
            return

        url = f"https://t.me/{username}"
        keyboard = InlineKeyboardMarkup(
            [[InlineKeyboardButton("فتح شات المطور" if lang == "ar" else "Open Developer Chat", url=url)]]
        )
        text = (
            "<b>تواصل مع المطور</b>\n\nدوس الزرار تحت لفتح شات مباشر مع المطور:"
            if lang == "ar" else
            "<b>Contact Developer</b>\n\nTap the button below to open a direct chat:"
        )
        await update.message.reply_text(text, parse_mode="HTML", reply_markup=keyboard)

    elif action == "admin_panel":
        if await db.is_admin(user_id):
            await admin_dashboard.cmd_admin(update, context)
        else:
            await update.message.reply_text(
                "🚫 <b>هذه الميزة للأدمن فقط.</b>", parse_mode="HTML"
            )


# ===================== دوال مساعدة =====================

async def _show_recent_downloads(update: Update, lang: str, user_id: int):
    rows = await db.get_recent_downloads(user_id, limit=5)

    if not rows:
        text = (
            "📜 <b>لسه مفيش تحميلات سابقة.</b>" if lang == "ar"
            else "📜 <b>No previous downloads yet.</b>"
        )
        await update.message.reply_text(text, parse_mode="HTML")
        return

    header = "📜 <b>آخر تحميلاتك</b>\n" if lang == "ar" else "📜 <b>Your recent downloads</b>\n"
    lines = [header]
    for url, site, fmt, created_at in rows:
        date_str = datetime.fromtimestamp(created_at).strftime("%Y-%m-%d %H:%M")
        short_url = url if len(url) <= 45 else url[:42] + "..."
        lines.append(f"• {short_url}\n  📌 {site} | {fmt} | 🕒 {date_str}")

    await update.message.reply_text("\n".join(lines), parse_mode="HTML")


async def _show_quality_picker(update: Update, lang: str):
    current = await get_default_quality(update.effective_user.id)
    current_label = f"{current}p" if current else ("غير محدد" if lang == "ar" else "Not set")

    text = (
        f"🎚️ <b>الجودة الافتراضية</b>\n\n• الحالية: {current_label}\n\nاختار جودة جديدة:"
        if lang == "ar" else
        f"🎚️ <b>Default Quality</b>\n\n• Current: {current_label}\n\nPick a new one:"
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
        msg = "✅ <b>تم إلغاء الجودة الافتراضية.</b>\n\nهتختار في كل مرة." if lang == "ar" else "✅ <b>Default quality cleared.</b>"
    else:
        await set_default_quality(user_id, value)
        msg = f"✅ <b>تم الحفظ</b>\n\n• الجودة الافتراضية: {value}p" if lang == "ar" else f"✅ <b>Saved</b>\n\n• Default quality: {value}p"

    await query.edit_message_text(msg, parse_mode="HTML")


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
            f"• User ID: <code>{user_id}</code>\n"
            f"• Username: {username}\n"
            f"• Joined: {joined_str}\n"
            f"• Total downloads: {downloads_count}\n"
            f"• Default quality: {quality_label}"
        )
    else:
        text = (
            f"🆔 <b>معلوماتي</b>\n\n"
            f"• آيدي تليجرام: <code>{user_id}</code>\n"
            f"• اسم المستخدم: {username}\n"
            f"• تاريخ الانضمام: {joined_str}\n"
            f"• عدد التحميلات الكلي: {downloads_count}\n"
            f"• الجودة الافتراضية: {quality_label}"
        )

    await update.message.reply_text(text, parse_mode="HTML")

ZEOF_MARKER_UNIQUE
echo "✅ تم تحديث handlers/menu.py"

echo "🔍 فحص الأكواد..."
python -m py_compile config.py bot.py handlers/menu.py
echo ""
echo "✅✅✅ تم بنجاح! ✅✅✅"
echo ""
echo "مهم جدًا: ضيف يوزرك في .env قبل ما ترفع:"
echo "  OWNER_USERNAME=يوزرك_بدون_@"
echo ""
echo "الخطوة الجاية:"
echo "  git add ."
echo "  git commit -m 'Contact Developer button opens direct chat'"
echo "  git push"
echo "  bash run.sh"