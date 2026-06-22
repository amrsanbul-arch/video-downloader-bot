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
        await update.message.reply_text(t("banned", lang))
        return
    lang = await db.get_user_language(user_id)
    await update.message.reply_text(t("help", lang))
