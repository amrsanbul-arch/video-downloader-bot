#!/data/data/com.termux/files/usr/bin/bash
# pro_start_and_developer_contact.sh
set -e
echo "🔧 تطبيق رسالة /start الجديدة وتسمية تواصل مع المطور..."

cat > 'languages/ar.json' << 'ZEOF_MARKER_UNIQUE'
{
  "start": "✨ <b>أهلاً بيك يا {name}</b> ✨\n\n━━━━━━━━━━━━━━━\n\n🎬 <b>بوت تحميل الفيديوهات</b>\nحمّل فيديوهاتك المفضلة من السوشيال ميديا بضغطة واحدة\n\n📲 <b>المنصات المدعومة:</b>\nYouTube • TikTok • Facebook\nInstagram • X (Twitter) • وغيرهم\n\n⚡ <b>المميزات:</b>\n• اختيار الجودة (144p → 1080p)\n• تحميل صوت MP3\n• استخراج صورة مصغرة\n• سريع وسهل الاستخدام\n\n━━━━━━━━━━━━━━━\n\n📥 ابعتلي رابط الفيديو دلوقتي وجرّب!\nأو استخدم القائمة تحت 👇",
  "help": "📖 <b>قائمة الأوامر</b>\n\n• /start — بدء استخدام البوت\n• /help — عرض هذه القائمة\n• /about — معلومات عن البوت\n• /settings — الإعدادات\n• /stats — إحصائياتك\n• /lang — تغيير اللغة\n• /ping — فحص سرعة استجابة البوت\n\n📥 لتحميل فيديو: ابعت الرابط مباشرة في الشات.",
  "about": "ℹ️ <b>عن البوت</b>\n\n• بوت تحميل فيديوهات احترافي\n• المنصات المدعومة: {sites}\n• مبني بـ Python + yt-dlp + python-telegram-bot",
  "ping": "🏓 <b>Pong!</b>\n\n• زمن الاستجابة: {ms} ms",
  "settings": "⚙️ <b>الإعدادات</b>\n\n• اللغة الحالية: {current_lang}\n\nلتغيير اللغة استخدم /lang",
  "stats_user": "📊 <b>إحصائياتك</b>\n\n• عدد التحميلات: {downloads}",
  "lang_choose": "🌐 <b>اختر لغتك:</b>",
  "lang_changed": "✅ <b>تم تغيير اللغة إلى العربية</b>",
  "banned": "🚫 <b>تم حظرك من استخدام هذا البوت.</b>",
  "rate_limited": "⏳ <b>كثرت عليها شوية!</b>\n\nاستنى لحظات وحاول تاني.",
  "invalid_url": "❌ <b>رابط غير صحيح</b>\n\nتأكد إن الموقع مدعوم.",
  "analyzing": "🔍 <b>جاري التحليل...</b>",
  "coming_soon": "🚧 <b>ميزة قيد التطوير</b>\n\nهتتفعل في المرحلة الجاية من المشروع."
}

ZEOF_MARKER_UNIQUE
echo "✅ تم تحديث languages/ar.json"

cat > 'languages/en.json' << 'ZEOF_MARKER_UNIQUE'
{
  "start": "✨ <b>Welcome, {name}</b> ✨\n\n━━━━━━━━━━━━━━━\n\n🎬 <b>Video Downloader Bot</b>\nDownload your favorite videos from social media in one tap\n\n📲 <b>Supported platforms:</b>\nYouTube • TikTok • Facebook\nInstagram • X (Twitter) • and more\n\n⚡ <b>Features:</b>\n• Choose quality (144p → 1080p)\n• Download MP3 audio\n• Extract thumbnail\n• Fast and easy to use\n\n━━━━━━━━━━━━━━━\n\n📥 Send me a video link now and try it!\nOr use the menu below 👇",
  "help": "📖 <b>Commands list</b>\n\n• /start — Start the bot\n• /help — Show this menu\n• /about — About this bot\n• /settings — Settings\n• /stats — Your stats\n• /lang — Change language\n• /ping — Check bot response time\n\n📥 To download a video: just send the link in chat.",
  "about": "ℹ️ <b>About this bot</b>\n\n• Professional video downloader bot\n• Supported platforms: {sites}\n• Built with Python + yt-dlp + python-telegram-bot",
  "ping": "🏓 <b>Pong!</b>\n\n• Response time: {ms} ms",
  "settings": "⚙️ <b>Settings</b>\n\n• Current language: {current_lang}\n\nTo change language use /lang",
  "stats_user": "📊 <b>Your stats</b>\n\n• Downloads: {downloads}",
  "lang_choose": "🌐 <b>Choose your language:</b>",
  "lang_changed": "✅ <b>Language changed to English</b>",
  "banned": "🚫 <b>You are banned from using this bot.</b>",
  "rate_limited": "⏳ <b>Slow down!</b>\n\nPlease wait a moment and try again.",
  "invalid_url": "❌ <b>Invalid link</b>\n\nMake sure the site is supported.",
  "analyzing": "🔍 <b>Analyzing...</b>",
  "coming_soon": "🚧 <b>Feature under development</b>\n\nWill be enabled in the next project phase."
}

ZEOF_MARKER_UNIQUE
echo "✅ تم تحديث languages/en.json"

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
        context.user_data["support_action"] = True
        if lang == "en":
            await update.message.reply_text(
                "<b>Contact Developer</b>\n\n"
                "• Write your message and it will be sent directly to the developer\n"
                "• Send /cancel to cancel",
                parse_mode="HTML",
            )
        else:
            await update.message.reply_text(
                "<b>تواصل مع المطور</b>\n\n"
                "• اكتب رسالتك وهتتبعت مباشرة للمطور\n"
                "• ابعت /cancel للإلغاء",
                parse_mode="HTML",
            )

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
    """تحويل رسالة التواصل مع المطور للأونر مباشرة"""
    context.user_data.pop("support_action", None)
    user = update.effective_user
    text = update.message.text

    try:
        await context.bot.send_message(
            chat_id=config.OWNER_ID,
            text=(
                f"📨 رسالة جديدة (تواصل مع المطور)\n\n"
                f"من: {user.first_name or ''} (@{user.username or '—'})\n"
                f"آيدي: {user.id}\n\n"
                f"الرسالة:\n{text}"
            ),
        )
        await update.message.reply_text(
            "✅ <b>تم إرسال رسالتك للمطور.</b>\n\nهيتم الرد عليك قريبًا.", parse_mode="HTML"
        )
    except Exception as e:
        logger.error(f"فشل تحويل الرسالة للمطور: {e}")
        await update.message.reply_text(
            "❌ <b>حصل خطأ أثناء إرسال رسالتك.</b>\n\nحاول تاني.", parse_mode="HTML"
        )


if __name__ == "__main__":
    main()

ZEOF_MARKER_UNIQUE
echo "✅ تم تحديث bot.py"

echo "🔍 فحص الأكواد..."
python -m py_compile bot.py handlers/menu.py
python3 -c "import json; json.load(open('languages/ar.json')); json.load(open('languages/en.json'))"
echo ""
echo "✅✅✅ تم بنجاح! ✅✅✅"
echo ""
echo "الخطوة الجاية:"
echo "  git add ."
echo "  git commit -m 'New professional start message + rename to Contact Developer'"
echo "  git push"
echo "  bash run.sh"