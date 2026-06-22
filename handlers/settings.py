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
    await update.message.reply_text(t("settings", lang, lang=lang))


async def cmd_stats(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_id = update.effective_user.id
    if await db.is_banned(user_id):
        lang = await db.get_user_language(user_id)
        await update.message.reply_text(t("banned", lang))
        return
    lang = await db.get_user_language(user_id)
    downloads_count = await db.count_user_downloads(user_id)
    await update.message.reply_text(t("stats_user", lang, downloads=downloads_count))
