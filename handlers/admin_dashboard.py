"""
handlers/admin_dashboard.py
لوحة إدارة احترافية بأزرار تفاعلية (Dashboard بدل أوامر نصية)
"""

import asyncio
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import ContextTypes

from database.models import db
from utils.logger import logger


async def is_admin_check(update: Update) -> bool:
    return await db.is_admin(update.effective_user.id)


async def cmd_admin(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """فتح لوحة الإدارة الرئيسية"""
    if not await is_admin_check(update):
        await update.message.reply_text("🚫 أنت لست أدمين.")
        return

    keyboard = InlineKeyboardMarkup(
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
    await update.message.reply_text("🛠️ لوحة الإدارة\n\nاختر عملية:", reply_markup=keyboard)


async def on_admin_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """معالجة جميع أزرار لوحة الإدارة"""
    query = update.callback_query
    await query.answer()

    if not await is_admin_check(update):
        await query.edit_message_text("🚫 أنت لست أدمين.")
        return

    action = query.data

    if action == "admin_users":
        count = await db.count_users()
        await query.edit_message_text(f"👥 عدد المستخدمين: {count}")

    elif action == "admin_stats":
        users_count = await db.count_users()
        downloads_count = await db.count_downloads()
        text = f"""
📊 إحصائيات البوت:

👥 المستخدمين: {users_count}
📥 التحميلات: {downloads_count}
"""
        keyboard = InlineKeyboardMarkup(
            [[InlineKeyboardButton("🔙 رجوع", callback_data="admin_back")]]
        )
        await query.edit_message_text(text, reply_markup=keyboard)

    elif action == "admin_broadcast_menu":
        await query.edit_message_text(
            "📢 برودكاست\n\nابعتلي الرسالة اللي تبي تبرودكاست بيها",
            reply_markup=InlineKeyboardMarkup(
                [[InlineKeyboardButton("🔙 رجوع", callback_data="admin_back")]]
            ),
        )
        context.user_data["admin_action"] = "broadcast"

    elif action == "admin_ban_menu":
        keyboard = InlineKeyboardMarkup(
            [
                [InlineKeyboardButton("🚫 حظر مستخدم", callback_data="admin_ban_user")],
                [
                    InlineKeyboardButton(
                        "✅ رفع حظر", callback_data="admin_unban_user"
                    )
                ],
                [InlineKeyboardButton("🔙 رجوع", callback_data="admin_back")],
            ]
        )
        await query.edit_message_text(
            "🚫 إدارة الحظر\n\nاختر:", reply_markup=keyboard
        )

    elif action == "admin_ban_user":
        await query.edit_message_text(
            "ابعت آيدي المستخدم اللي تبي تحظره",
            reply_markup=InlineKeyboardMarkup(
                [[InlineKeyboardButton("🔙 رجوع", callback_data="admin_back")]]
            ),
        )
        context.user_data["admin_action"] = "ban_user"

    elif action == "admin_unban_user":
        await query.edit_message_text(
            "ابعت آيدي المستخدم اللي تبي ترفع حظره",
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
            await query.edit_message_text("لا يوجد ملف سجل حتى الآن.")

    elif action == "admin_update":
        await query.edit_message_text("⬇️ جاري سحب التحديثات...")
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
                chat_id=query.message.chat_id, text=f"❌ فشل التحديث: {e}"
            )

    elif action == "admin_restart":
        await query.edit_message_text("🔄 جاري إعادة التشغيل...")
        logger.info("إعادة تشغيل البوت بأمر من الأدمن")
        import sys

        sys.exit(0)

    elif action == "admin_back":
        keyboard = InlineKeyboardMarkup(
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
        await query.edit_message_text("🛠️ لوحة الإدارة\n\nاختر عملية:", reply_markup=keyboard)

    elif action == "admin_close":
        await query.edit_message_text("✅ تم الإغلاق.")


async def on_admin_text_input(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """معالجة إدخالات نصية من الأدمن (برودكاست، حظر، إلخ)"""
    if not await is_admin_check(update):
        return

    action = context.user_data.get("admin_action")

    if action == "broadcast":
        message = update.message.text
        user_ids = await db.get_all_user_ids()
        sent, failed = 0, 0
        status_msg = await update.message.reply_text("📢 جاري الإرسال...")

        for uid in user_ids:
            try:
                await context.bot.send_message(chat_id=uid, text=f"📢 {message}")
                sent += 1
            except Exception as e:
                failed += 1
                logger.warning(f"فشل إرسال البرودكاست للمستخدم {uid}: {e}")
            await asyncio.sleep(0.05)

        await status_msg.edit_text(
            f"✅ تم الإرسال لـ {sent} مستخدم\n❌ فشل: {failed}"
        )
        context.user_data.pop("admin_action", None)

    elif action == "ban_user":
        try:
            target_id = int(update.message.text)
            await db.ban_user(target_id)
            await update.message.reply_text(f"🚫 تم حظر المستخدم {target_id}")
        except ValueError:
            await update.message.reply_text("⚠️ آيدي غير صحيح.")
        context.user_data.pop("admin_action", None)

    elif action == "unban_user":
        try:
            target_id = int(update.message.text)
            await db.unban_user(target_id)
            await update.message.reply_text(f"✅ تم رفع الحظر عن المستخدم {target_id}")
        except ValueError:
            await update.message.reply_text("⚠️ آيدي غير صحيح.")
        context.user_data.pop("admin_action", None)
