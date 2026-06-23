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
