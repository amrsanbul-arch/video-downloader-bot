"""
handlers/force_subscribe.py
نظام Force Subscribe
"""

from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import ContextTypes
from telegram.error import TelegramError

from config import config
from utils.logger import logger


async def check_subscription(update: Update, context: ContextTypes.DEFAULT_TYPE) -> bool:
    channel = getattr(config, "FORCE_SUBSCRIBE_CHANNEL", None)
    if not channel:
        return True

    user_id = update.effective_user.id
    chat_id = channel if channel.startswith("@") else f"@{channel}"

    try:
        member = await context.bot.get_chat_member(chat_id=chat_id, user_id=user_id)
        if member.status in ["member", "administrator", "creator"]:
            return True
    except TelegramError:
        logger.warning(f"فشل التحقق من اشتراك المستخدم {user_id} في القناة {channel}")
    except Exception as e:
        logger.error(f"خطأ في check_subscription: {e}")

    return False


async def send_subscribe_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    channel = getattr(config, "FORCE_SUBSCRIBE_CHANNEL", None)
    if not channel:
        return

    keyboard = InlineKeyboardMarkup(
        [[InlineKeyboardButton("✅ اشترك في القناة", url=f"https://t.me/{channel}")]]
    )

    await update.message.reply_text(
        "🔒 لازم تكون مشترك في القناة قبل ما تحمّل!\n\nاشترك في القناة وحاول تاني.",
        reply_markup=keyboard,
    )
