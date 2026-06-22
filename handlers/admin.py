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
    await update.message.reply_text(f"👥 عدد المستخدمين: {count}")


async def cmd_botstats(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not await is_admin_check(update):
        return
    users_count = await db.count_users()
    downloads_count = await db.count_downloads()
    await update.message.reply_text(
        f"📊 إحصائيات البوت:\n\n👥 المستخدمين: {users_count}\n📥 التحميلات: {downloads_count}"
    )


async def cmd_ban(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not await is_admin_check(update):
        return
    if not context.args:
        await update.message.reply_text("الاستخدام: /ban <user_id> [السبب]")
        return
    try:
        target_id = int(context.args[0])
    except ValueError:
        await update.message.reply_text("⚠️ آيدي غير صحيح.")
        return
    reason = " ".join(context.args[1:]) if len(context.args) > 1 else ""
    await db.ban_user(target_id, reason)
    await update.message.reply_text(f"🚫 تم حظر المستخدم {target_id}")


async def cmd_unban(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not await is_admin_check(update):
        return
    if not context.args:
        await update.message.reply_text("الاستخدام: /unban <user_id>")
        return
    try:
        target_id = int(context.args[0])
    except ValueError:
        await update.message.reply_text("⚠️ آيدي غير صحيح.")
        return
    await db.unban_user(target_id)
    await update.message.reply_text(f"✅ تم رفع الحظر عن المستخدم {target_id}")


async def cmd_broadcast(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not await is_admin_check(update):
        return
    if not context.args:
        await update.message.reply_text("الاستخدام: /broadcast <الرسالة>")
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
    await update.message.reply_text(f"✅ تم الإرسال لـ {sent} مستخدم\n❌ فشل: {failed}")


async def cmd_logs(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not await is_admin_check(update):
        return
    try:
        with open("logs/bot.log", "rb") as f:
            await update.message.reply_document(f, filename="bot.log")
    except FileNotFoundError:
        await update.message.reply_text("لا يوجد ملف سجل حتى الآن.")


async def cmd_restart(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """إعادة تشغيل العملية الحالية (يتطلب مدير عمليات مثل pm2 أو screen أو systemd)"""
    if not await is_admin_check(update):
        return
    await update.message.reply_text("🔄 جاري إعادة تشغيل البوت...")
    logger.info("إعادة تشغيل البوت بأمر من الأدمن")
    # إعادة تشغيل نفس العملية بنفس الـ python والـ args
    sys.exit(0)


async def cmd_update(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """تحديث المشروع عبر git pull (يتطلب أن يكون المجلد مستنسخ Git repo)"""
    if not await is_admin_check(update):
        return
    await update.message.reply_text("⬇️ جاري سحب آخر تحديثات من GitHub...")
    try:
        result = subprocess.run(
            ["git", "pull"], capture_output=True, text=True, timeout=60
        )
        output = result.stdout + result.stderr
        await update.message.reply_text(f"```\n{output[:3500]}\n```", parse_mode="Markdown")
    except Exception as e:
        await update.message.reply_text(f"❌ فشل التحديث: {e}")
