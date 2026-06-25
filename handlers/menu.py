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

