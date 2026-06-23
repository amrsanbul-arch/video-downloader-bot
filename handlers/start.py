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
