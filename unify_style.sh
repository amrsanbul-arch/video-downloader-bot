#!/data/data/com.termux/files/usr/bin/bash
# unify_style.sh
set -e
echo "🔧 تطبيق ستايل موحّد على كل رسائل البوت..."

mkdir -p $(dirname 'languages/ar.json')
cat > 'languages/ar.json' << 'ZEOF_MARKER_UNIQUE'
{
  "start": "👋 <b>أهلاً بيك يا {name}!</b>\n\n• أنا بوت تحميل فيديوهات من السوشيال ميديا\n• يوتيوب، تيك توك، فيسبوك، انستجرام، تويتر/X، وغيرهم\n\n📥 ابعتلي رابط الفيديو وهتلاقي خيارات التحميل تظهرلك.\n\nاكتب /help لمعرفة كل الأوامر.",
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

mkdir -p $(dirname 'languages/en.json')
cat > 'languages/en.json' << 'ZEOF_MARKER_UNIQUE'
{
  "start": "👋 <b>Hello {name}!</b>\n\n• I'm a social media video downloader bot\n• YouTube, TikTok, Facebook, Instagram, X/Twitter, and more\n\n📥 Send me a video link and download options will appear.\n\nType /help to see all commands.",
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
        await update.message.reply_text(t("banned", lang), parse_mode="HTML")
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
        t("start", lang, name=name),
        parse_mode="HTML",
        reply_markup=build_main_menu(lang, is_admin),
    )


async def cmd_about(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if await check_banned(update):
        return
    lang = await get_lang(update.effective_user.id)
    sites = "، ".join(config.SUPPORTED_SITES)
    await update.message.reply_text(t("about", lang, sites=sites), parse_mode="HTML")


async def cmd_ping(update: Update, context: ContextTypes.DEFAULT_TYPE):
    start = time.monotonic()
    lang = await get_lang(update.effective_user.id)
    msg = await update.message.reply_text("🏓 ...")
    elapsed_ms = int((time.monotonic() - start) * 1000)
    await msg.edit_text(t("ping", lang, ms=elapsed_ms), parse_mode="HTML")


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
    await update.message.reply_text(
        t("lang_choose", lang), parse_mode="HTML", reply_markup=keyboard
    )


async def on_lang_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    new_lang = query.data.replace("setlang_", "")
    await db.set_user_language(query.from_user.id, new_lang)
    await query.edit_message_text(t("lang_changed", new_lang), parse_mode="HTML")
    is_admin = await db.is_admin(query.from_user.id)
    await context.bot.send_message(
        chat_id=query.message.chat_id,
        text="🔄",
        reply_markup=build_main_menu(new_lang, is_admin),
    )

ZEOF_MARKER_UNIQUE
echo "✅ تم تحديث handlers/start.py"

mkdir -p $(dirname 'handlers/help.py')
cat > 'handlers/help.py' << 'ZEOF_MARKER_UNIQUE'
"""
handlers/help.py
أمر /help لعرض قائمة الأوامر المتاحة
"""

from telegram import Update
from telegram.ext import ContextTypes

from database.models import db
from utils.i18n import t


async def cmd_help(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_id = update.effective_user.id
    if await db.is_banned(user_id):
        lang = await db.get_user_language(user_id)
        await update.message.reply_text(t("banned", lang), parse_mode="HTML")
        return
    lang = await db.get_user_language(user_id)
    await update.message.reply_text(t("help", lang), parse_mode="HTML")

ZEOF_MARKER_UNIQUE
echo "✅ تم تحديث handlers/help.py"

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
        await update.message.reply_text(t("banned", lang), parse_mode="HTML")
        return
    lang = await db.get_user_language(user_id)
    await update.message.reply_text(
        t("settings", lang, current_lang=lang), parse_mode="HTML"
    )


async def cmd_stats(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_id = update.effective_user.id
    if await db.is_banned(user_id):
        lang = await db.get_user_language(user_id)
        await update.message.reply_text(t("banned", lang), parse_mode="HTML")
        return
    lang = await db.get_user_language(user_id)
    downloads_count = await db.count_user_downloads(user_id)
    await update.message.reply_text(
        t("stats_user", lang, downloads=downloads_count), parse_mode="HTML"
    )

ZEOF_MARKER_UNIQUE
echo "✅ تم تحديث handlers/settings.py"

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

ZEOF_MARKER_UNIQUE
echo "✅ تم تحديث handlers/download.py"

mkdir -p $(dirname 'handlers/admin_dashboard.py')
cat > 'handlers/admin_dashboard.py' << 'ZEOF_MARKER_UNIQUE'
"""
handlers/admin_dashboard.py
لوحة إدارة احترافية بأزرار تفاعلية (Dashboard بدل أوامر نصية)
"""

import asyncio
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import ContextTypes

from database.models import db
from utils.logger import logger


def _main_keyboard() -> InlineKeyboardMarkup:
    return InlineKeyboardMarkup(
        [
            [InlineKeyboardButton("👥 المستخدمين", callback_data="admin_users")],
            [InlineKeyboardButton("📊 الإحصائيات", callback_data="admin_stats")],
            [InlineKeyboardButton("📢 برودكاست", callback_data="admin_broadcast_menu")],
            [InlineKeyboardButton("🚫 حظر/رفع حظر", callback_data="admin_ban_menu")],
            [InlineKeyboardButton("📝 السجلات", callback_data="admin_logs")],
            [InlineKeyboardButton("🔄 تحديث", callback_data="admin_update")],
            [InlineKeyboardButton("🔌 إعادة تشغيل", callback_data="admin_restart")],
            [InlineKeyboardButton("❌ إغلاق", callback_data="admin_close")],
        ]
    )


async def is_admin_check(update: Update) -> bool:
    return await db.is_admin(update.effective_user.id)


async def cmd_admin(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """فتح لوحة الإدارة الرئيسية"""
    if not await is_admin_check(update):
        await update.message.reply_text("🚫 <b>أنت لست أدمين.</b>", parse_mode="HTML")
        return

    await update.message.reply_text(
        "🛠️ <b>لوحة الإدارة</b>\n\nاختر عملية:",
        parse_mode="HTML",
        reply_markup=_main_keyboard(),
    )


async def on_admin_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """معالجة جميع أزرار لوحة الإدارة"""
    query = update.callback_query
    await query.answer()

    if not await is_admin_check(update):
        await query.edit_message_text("🚫 <b>أنت لست أدمين.</b>", parse_mode="HTML")
        return

    action = query.data

    if action == "admin_users":
        count = await db.count_users()
        keyboard = InlineKeyboardMarkup([[InlineKeyboardButton("🔙 رجوع", callback_data="admin_back")]])
        await query.edit_message_text(
            f"👥 <b>المستخدمين</b>\n\n• العدد الكلي: {count}",
            parse_mode="HTML",
            reply_markup=keyboard,
        )

    elif action == "admin_stats":
        users_count = await db.count_users()
        downloads_count = await db.count_downloads()
        text = (
            f"📊 <b>إحصائيات البوت</b>\n\n"
            f"• المستخدمين: {users_count}\n"
            f"• التحميلات: {downloads_count}"
        )
        keyboard = InlineKeyboardMarkup(
            [[InlineKeyboardButton("🔙 رجوع", callback_data="admin_back")]]
        )
        await query.edit_message_text(text, parse_mode="HTML", reply_markup=keyboard)

    elif action == "admin_broadcast_menu":
        await query.edit_message_text(
            "📢 <b>برودكاست</b>\n\nابعتلي الرسالة اللي تبي تبرودكاست بيها.",
            parse_mode="HTML",
            reply_markup=InlineKeyboardMarkup(
                [[InlineKeyboardButton("🔙 رجوع", callback_data="admin_back")]]
            ),
        )
        context.user_data["admin_action"] = "broadcast"

    elif action == "admin_ban_menu":
        keyboard = InlineKeyboardMarkup(
            [
                [InlineKeyboardButton("🚫 حظر مستخدم", callback_data="admin_ban_user")],
                [InlineKeyboardButton("✅ رفع حظر", callback_data="admin_unban_user")],
                [InlineKeyboardButton("🔙 رجوع", callback_data="admin_back")],
            ]
        )
        await query.edit_message_text(
            "🚫 <b>إدارة الحظر</b>\n\nاختر العملية:", parse_mode="HTML", reply_markup=keyboard
        )

    elif action == "admin_ban_user":
        await query.edit_message_text(
            "🚫 <b>حظر مستخدم</b>\n\nابعت آيدي المستخدم اللي تبي تحظره.",
            parse_mode="HTML",
            reply_markup=InlineKeyboardMarkup(
                [[InlineKeyboardButton("🔙 رجوع", callback_data="admin_back")]]
            ),
        )
        context.user_data["admin_action"] = "ban_user"

    elif action == "admin_unban_user":
        await query.edit_message_text(
            "✅ <b>رفع حظر</b>\n\nابعت آيدي المستخدم اللي تبي ترفع حظره.",
            parse_mode="HTML",
            reply_markup=InlineKeyboardMarkup(
                [[InlineKeyboardButton("🔙 رجوع", callback_data="admin_back")]]
            ),
        )
        context.user_data["admin_action"] = "unban_user"

    elif action == "admin_logs":
        try:
            with open("logs/bot.log", "rb") as f:
                await context.bot.send_document(
                    chat_id=query.message.chat_id, document=f, filename="bot.log"
                )
        except FileNotFoundError:
            await query.edit_message_text(
                "📝 <b>لا يوجد ملف سجل حتى الآن.</b>", parse_mode="HTML"
            )

    elif action == "admin_update":
        await query.edit_message_text("⬇️ <b>جاري سحب التحديثات...</b>", parse_mode="HTML")
        import subprocess

        try:
            result = subprocess.run(
                ["git", "pull"], capture_output=True, text=True, timeout=60
            )
            output = result.stdout + result.stderr
            await context.bot.send_message(
                chat_id=query.message.chat_id,
                text=f"```\n{output[:3500]}\n```",
                parse_mode="Markdown",
            )
        except Exception as e:
            await context.bot.send_message(
                chat_id=query.message.chat_id,
                text=f"❌ <b>فشل التحديث</b>\n\n{e}",
                parse_mode="HTML",
            )

    elif action == "admin_restart":
        await query.edit_message_text("🔄 <b>جاري إعادة التشغيل...</b>", parse_mode="HTML")
        logger.info("إعادة تشغيل البوت بأمر من الأدمن")
        import sys

        sys.exit(0)

    elif action == "admin_back":
        await query.edit_message_text(
            "🛠️ <b>لوحة الإدارة</b>\n\nاختر عملية:",
            parse_mode="HTML",
            reply_markup=_main_keyboard(),
        )

    elif action == "admin_close":
        await query.edit_message_text("✅ <b>تم الإغلاق.</b>", parse_mode="HTML")


async def on_admin_text_input(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """معالجة إدخالات نصية من الأدمن (برودكاست، حظر، إلخ)"""
    if not await is_admin_check(update):
        return

    action = context.user_data.get("admin_action")

    if action == "broadcast":
        message = update.message.text
        user_ids = await db.get_all_user_ids()
        sent, failed = 0, 0
        status_msg = await update.message.reply_text(
            "📢 <b>جاري الإرسال...</b>", parse_mode="HTML"
        )

        for uid in user_ids:
            try:
                await context.bot.send_message(chat_id=uid, text=f"📢 {message}")
                sent += 1
            except Exception as e:
                failed += 1
                logger.warning(f"فشل إرسال البرودكاست للمستخدم {uid}: {e}")
            await asyncio.sleep(0.05)

        await status_msg.edit_text(
            f"✅ <b>تم الإرسال</b>\n\n• نجح: {sent}\n• فشل: {failed}",
            parse_mode="HTML",
        )
        context.user_data.pop("admin_action", None)

    elif action == "ban_user":
        try:
            target_id = int(update.message.text)
            await db.ban_user(target_id)
            await update.message.reply_text(
                f"🚫 <b>تم حظر المستخدم</b>\n\n• الآيدي: {target_id}", parse_mode="HTML"
            )
        except ValueError:
            await update.message.reply_text("⚠️ <b>آيدي غير صحيح.</b>", parse_mode="HTML")
        context.user_data.pop("admin_action", None)

    elif action == "unban_user":
        try:
            target_id = int(update.message.text)
            await db.unban_user(target_id)
            await update.message.reply_text(
                f"✅ <b>تم رفع الحظر</b>\n\n• الآيدي: {target_id}", parse_mode="HTML"
            )
        except ValueError:
            await update.message.reply_text("⚠️ <b>آيدي غير صحيح.</b>", parse_mode="HTML")
        context.user_data.pop("admin_action", None)

ZEOF_MARKER_UNIQUE
echo "✅ تم تحديث handlers/admin_dashboard.py"

mkdir -p $(dirname 'handlers/admin.py')
cat > 'handlers/admin.py' << 'ZEOF_MARKER_UNIQUE'
"""
handlers/admin.py
أوامر لوحة الإدارة: broadcast, users, stats, ban, unban, logs, restart, update
"""

import asyncio
import subprocess
import sys
from telegram import Update
from telegram.ext import ContextTypes

from database.models import db
from utils.logger import logger


async def is_admin_check(update: Update) -> bool:
    return await db.is_admin(update.effective_user.id)


async def cmd_users(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not await is_admin_check(update):
        return
    count = await db.count_users()
    await update.message.reply_text(
        f"👥 <b>المستخدمين</b>\n\n• العدد الكلي: {count}", parse_mode="HTML"
    )


async def cmd_botstats(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not await is_admin_check(update):
        return
    users_count = await db.count_users()
    downloads_count = await db.count_downloads()
    await update.message.reply_text(
        f"📊 <b>إحصائيات البوت</b>\n\n"
        f"• المستخدمين: {users_count}\n"
        f"• التحميلات: {downloads_count}",
        parse_mode="HTML",
    )


async def cmd_ban(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not await is_admin_check(update):
        return
    if not context.args:
        await update.message.reply_text(
            "ℹ️ <b>الاستخدام</b>\n\n<code>/ban &lt;user_id&gt; [السبب]</code>",
            parse_mode="HTML",
        )
        return
    try:
        target_id = int(context.args[0])
    except ValueError:
        await update.message.reply_text("⚠️ <b>آيدي غير صحيح.</b>", parse_mode="HTML")
        return
    reason = " ".join(context.args[1:]) if len(context.args) > 1 else ""
    await db.ban_user(target_id, reason)
    await update.message.reply_text(
        f"🚫 <b>تم حظر المستخدم</b>\n\n• الآيدي: {target_id}", parse_mode="HTML"
    )


async def cmd_unban(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not await is_admin_check(update):
        return
    if not context.args:
        await update.message.reply_text(
            "ℹ️ <b>الاستخدام</b>\n\n<code>/unban &lt;user_id&gt;</code>",
            parse_mode="HTML",
        )
        return
    try:
        target_id = int(context.args[0])
    except ValueError:
        await update.message.reply_text("⚠️ <b>آيدي غير صحيح.</b>", parse_mode="HTML")
        return
    await db.unban_user(target_id)
    await update.message.reply_text(
        f"✅ <b>تم رفع الحظر</b>\n\n• الآيدي: {target_id}", parse_mode="HTML"
    )


async def cmd_broadcast(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not await is_admin_check(update):
        return
    if not context.args:
        await update.message.reply_text(
            "ℹ️ <b>الاستخدام</b>\n\n<code>/broadcast &lt;الرسالة&gt;</code>",
            parse_mode="HTML",
        )
        return
    message = " ".join(context.args)
    user_ids = await db.get_all_user_ids()
    sent, failed = 0, 0
    for uid in user_ids:
        try:
            await context.bot.send_message(chat_id=uid, text=f"📢 {message}")
            sent += 1
        except Exception as e:
            failed += 1
            logger.warning(f"فشل إرسال البرودكاست للمستخدم {uid}: {e}")
        await asyncio.sleep(0.05)  # تجنب حظر تليجرام بسبب السبام
    await update.message.reply_text(
        f"✅ <b>تم الإرسال</b>\n\n• نجح: {sent}\n• فشل: {failed}", parse_mode="HTML"
    )


async def cmd_logs(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not await is_admin_check(update):
        return
    try:
        with open("logs/bot.log", "rb") as f:
            await update.message.reply_document(f, filename="bot.log")
    except FileNotFoundError:
        await update.message.reply_text(
            "📝 <b>لا يوجد ملف سجل حتى الآن.</b>", parse_mode="HTML"
        )


async def cmd_restart(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """إعادة تشغيل العملية الحالية (يتطلب مدير عمليات مثل pm2 أو screen أو systemd)"""
    if not await is_admin_check(update):
        return
    await update.message.reply_text("🔄 <b>جاري إعادة تشغيل البوت...</b>", parse_mode="HTML")
    logger.info("إعادة تشغيل البوت بأمر من الأدمن")
    sys.exit(0)


async def cmd_update(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """تحديث المشروع عبر git pull (يتطلب أن يكون المجلد مستنسخ Git repo)"""
    if not await is_admin_check(update):
        return
    await update.message.reply_text(
        "⬇️ <b>جاري سحب آخر تحديثات من GitHub...</b>", parse_mode="HTML"
    )
    try:
        result = subprocess.run(
            ["git", "pull"], capture_output=True, text=True, timeout=60
        )
        output = result.stdout + result.stderr
        await update.message.reply_text(f"```\n{output[:3500]}\n```", parse_mode="Markdown")
    except Exception as e:
        await update.message.reply_text(f"❌ <b>فشل التحديث</b>\n\n{e}", parse_mode="HTML")

ZEOF_MARKER_UNIQUE
echo "✅ تم تحديث handlers/admin.py"

mkdir -p $(dirname 'handlers/force_subscribe.py')
cat > 'handlers/force_subscribe.py' << 'ZEOF_MARKER_UNIQUE'
"""
handlers/force_subscribe.py
نظام Force Subscribe - المستخدم لازم يكون في القناة قبل ما يحمّل
(يمكن تعطيله في .env بـ FORCE_SUBSCRIBE_CHANNEL=)
"""

from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import ContextTypes
from telegram.error import TelegramError

from config import config
from database.models import db
from utils.logger import logger


async def check_subscription(update: Update, context: ContextTypes.DEFAULT_TYPE) -> bool:
    """
    التحقق من اشتراك المستخدم في القناة
    يرجع True إذا كان مشترك أو Force Subscribe معطّل
    """
    channel = getattr(config, "FORCE_SUBSCRIBE_CHANNEL", None)
    if not channel:
        return True  # Force Subscribe معطّل

    user_id = update.effective_user.id
    chat_id = channel if channel.startswith("@") else f"@{channel}"

    try:
        member = await context.bot.get_chat_member(chat_id=chat_id, user_id=user_id)
        # التحقق إذا كان الحالة "member" أو أعلى (admin, creator, إلخ)
        if member.status in ["member", "administrator", "creator"]:
            return True
    except TelegramError:
        logger.warning(f"فشل التحقق من اشتراك المستخدم {user_id} في القناة {channel}")
    except Exception as e:
        logger.error(f"خطأ في check_subscription: {e}")

    return False


async def send_subscribe_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """إرسال رسالة تطلب من المستخدم الاشتراك في القناة"""
    channel = getattr(config, "FORCE_SUBSCRIBE_CHANNEL", None)
    if not channel:
        return

    keyboard = InlineKeyboardMarkup(
        [
            [
                InlineKeyboardButton(
                    "✅ اشترك في القناة",
                    url=f"https://t.me/{channel}",
                )
            ]
        ]
    )

    await update.message.reply_text(
        "🔒 <b>لازم تكون مشترك في القناة قبل ما تحمّل!</b>\n\nاشترك في القناة وحاول تاني.",
        parse_mode="HTML",
        reply_markup=keyboard,
    )

ZEOF_MARKER_UNIQUE
echo "✅ تم تحديث handlers/force_subscribe.py"

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
                "📞 <b>Contact Support</b>\n\n"
                "• Write your message and it will be sent directly to the admin\n"
                "• Send /cancel to cancel",
                parse_mode="HTML",
            )
        else:
            await update.message.reply_text(
                "📞 <b>تواصل مع الدعم</b>\n\n"
                "• اكتب رسالتك وهتتبعت مباشرة للأدمن\n"
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
        await update.message.reply_text(
            "✅ <b>تم إرسال رسالتك للدعم.</b>\n\nهيتم الرد عليك قريبًا.", parse_mode="HTML"
        )
    except Exception as e:
        logger.error(f"فشل تحويل رسالة الدعم: {e}")
        await update.message.reply_text(
            "❌ <b>حصل خطأ أثناء إرسال رسالتك.</b>\n\nحاول تاني.", parse_mode="HTML"
        )


if __name__ == "__main__":
    main()

ZEOF_MARKER_UNIQUE
echo "✅ تم تحديث bot.py"

echo "🔍 فحص الأكواد..."
python -m py_compile bot.py handlers/*.py
python3 -c "import json; json.load(open('languages/ar.json')); json.load(open('languages/en.json'))"
echo ""
echo "✅✅✅ تم تطبيق الستايل الموحّد على كل الرسائل بنجاح! ✅✅✅"
echo ""
echo "الخطوة الجاية:"
echo "  git add ."
echo "  git commit -m 'Unify message style with bold headers and bullets'"
echo "  git push"
echo "  bash run.sh"