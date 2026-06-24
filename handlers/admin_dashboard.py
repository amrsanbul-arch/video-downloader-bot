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

