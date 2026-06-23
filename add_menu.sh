#!/data/data/com.termux/files/usr/bin/bash
# add_menu.sh
# سكريبت يضيف قائمة أزرار ثابتة في الشريط السفلي (Reply Keyboard)

set -e

echo "🔧 بدء إضافة القائمة الثابتة..."

# ===== 1: ملف جديد handlers/menu.py =====
cat > handlers/menu.py << 'EOF'
"""
handlers/menu.py
قائمة أزرار ثابتة (Reply Keyboard) تظهر في شريط الكتابة السفلي
"""

from telegram import Update, ReplyKeyboardMarkup, KeyboardButton
from telegram.ext import ContextTypes

from database.models import db


def build_main_menu(lang: str = "ar") -> ReplyKeyboardMarkup:
    """بناء القائمة الرئيسية الثابتة"""
    if lang == "en":
        buttons = [
            [KeyboardButton("📥 Download"), KeyboardButton("ℹ️ Help")],
            [KeyboardButton("⚙️ Settings"), KeyboardButton("📊 My Stats")],
            [KeyboardButton("🌐 Language"), KeyboardButton("🏓 Ping")],
        ]
    else:
        buttons = [
            [KeyboardButton("📥 تحميل فيديو"), KeyboardButton("ℹ️ المساعدة")],
            [KeyboardButton("⚙️ الإعدادات"), KeyboardButton("📊 إحصائياتي")],
            [KeyboardButton("🌐 اللغة"), KeyboardButton("🏓 فحص السرعة")],
        ]

    return ReplyKeyboardMarkup(
        buttons,
        resize_keyboard=True,
        is_persistent=True,
    )


async def get_lang(user_id: int) -> str:
    return await db.get_user_language(user_id)


BUTTON_TEXTS_AR = {
    "📥 تحميل فيديو": "download_info",
    "ℹ️ المساعدة": "help",
    "⚙️ الإعدادات": "settings",
    "📊 إحصائياتي": "stats",
    "🌐 اللغة": "lang",
    "🏓 فحص السرعة": "ping",
}

BUTTON_TEXTS_EN = {
    "📥 Download": "download_info",
    "ℹ️ Help": "help",
    "⚙️ Settings": "settings",
    "📊 My Stats": "stats",
    "🌐 Language": "lang",
    "🏓 Ping": "ping",
}

ALL_BUTTON_TEXTS = set(BUTTON_TEXTS_AR.keys()) | set(BUTTON_TEXTS_EN.keys())


def get_button_action(text: str):
    return BUTTON_TEXTS_AR.get(text) or BUTTON_TEXTS_EN.get(text)


async def is_menu_button(update: Update) -> bool:
    text = update.message.text if update.message else None
    return text in ALL_BUTTON_TEXTS if text else False


async def handle_menu_button(update: Update, context: ContextTypes.DEFAULT_TYPE):
    from handlers import help as help_handler, settings, start

    text = update.message.text
    action = get_button_action(text)

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
        lang = await get_lang(update.effective_user.id)
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
EOF
echo "✅ تم إنشاء handlers/menu.py"

# ===== 2: تحديث handlers/start.py =====
cat > handlers/start.py << 'EOF'
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
    await update.message.reply_text(
        t("start", lang, name=name), reply_markup=build_main_menu(lang)
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
    await context.bot.send_message(
        chat_id=query.message.chat_id,
        text="🔄",
        reply_markup=build_main_menu(new_lang),
    )
EOF
echo "✅ تم تحديث handlers/start.py"

# ===== 3: تحديث bot.py =====
cat > bot.py << 'EOF'
"""
bot.py - النسخة 2.2
- لوحة إدارة كاملة
- اختيار جودة دقيقة
- Force Subscribe
- شريط تقدم
- قائمة أزرار ثابتة (Reply Keyboard)
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
    app.add_handler(
        CallbackQueryHandler(admin_dashboard.on_admin_callback, pattern="^admin_")
    )

    async def on_text_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
        if await menu.is_menu_button(update):
            await menu.handle_menu_button(update, context)
            return

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
echo "✅ تم تحديث bot.py"

# ===== فحص الصياغة =====
echo "🔍 فحص الأكواد..."
python -m py_compile bot.py handlers/menu.py handlers/start.py

echo ""
echo "✅✅✅ تم إضافة القائمة الثابتة بنجاح! ✅✅✅"
echo ""
echo "الخطوة الجاية:"
echo "  git add ."
echo "  git commit -m 'Add persistent reply keyboard menu'"
echo "  git push"
echo "  python bot.py"
echo ""
echo "بعد التشغيل، ابعت /start عشان القائمة تظهر تحت في الشات"
