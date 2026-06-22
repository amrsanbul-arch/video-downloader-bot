"""لوحة الإدارة"""
import asyncio
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import ContextTypes
from database.models import db

async def is_admin_check(update: Update) -> bool:
    return await db.is_admin(update.effective_user.id)

async def cmd_admin(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not await is_admin_check(update):
        await update.message.reply_text("🚫 أنت لست أدمين.")
        return
    keyboard = InlineKeyboardMarkup([
        [InlineKeyboardButton("👥 المستخدمين", callback_data="admin_users")],
        [InlineKeyboardButton("📊 الإحصائيات", callback_data="admin_stats")],
        [InlineKeyboardButton("📢 برودكاست", callback_data="admin_broadcast_menu")],
        [InlineKeyboardButton("🚫 حظر/رفع حظر", callback_data="admin_ban_menu")],
        [InlineKeyboardButton("📝 السجلات", callback_data="admin_logs")],
        [InlineKeyboardButton("🔄 تحديث", callback_data="admin_update")],
        [InlineKeyboardButton("🔌 إعادة تشغيل", callback_data="admin_restart")],
        [InlineKeyboardButton("❌ إغلاق", callback_data="admin_close")],
    ])
    await update.message.reply_text("🛠️ لوحة الإدارة\n\nاختر عملية:", reply_markup=keyboard)

async def on_admin_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    if not await is_admin_check(update):
        await query.edit_message_text("🚫 أنت لست أدمين.")
        return
    action = query.data
    if action == "admin_users":
        count = await db.count_users()
        kb = InlineKeyboardMarkup([[InlineKeyboardButton("🔙 رجوع", callback_data="admin_back")]])
        await query.edit_message_text(f"👥 عدد المستخدمين: {count}", reply_markup=kb)
    elif action == "admin_stats":
        u = await db.count_users()
        d = await db.count_downloads()
        kb = InlineKeyboardMarkup([[InlineKeyboardButton("🔙 رجوع", callback_data="admin_back")]])
        await query.edit_message_text(f"📊 إحصائيات:\n👥 {u}\n📥 {d}", reply_markup=kb)
    elif action == "admin_back":
        kb = InlineKeyboardMarkup([
            [InlineKeyboardButton("👥 المستخدمين", callback_data="admin_users")],
            [InlineKeyboardButton("📊 الإحصائيات", callback_data="admin_stats")],
            [InlineKeyboardButton("❌ إغلاق", callback_data="admin_close")],
        ])
        await query.edit_message_text("🛠️ لوحة الإدارة:", reply_markup=kb)
    elif action == "admin_close":
        await query.edit_message_text("✅ تم.")

async def on_admin_text_input(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not await is_admin_check(update):
        return
