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

    try:
        member = await context.bot.get_chat_member(chat_id=channel, user_id=user_id)
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
        "🔒 لازم تكون مشترك في القناة قبل ما تحمّل!\n\nاشترك في القناة وحاول تاني.",
        reply_markup=keyboard,
    )
