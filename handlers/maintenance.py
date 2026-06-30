"""
handlers/maintenance.py
أوامر صيانة للأدمن:
- /health: استخدام CPU/RAM/Disk، مدة التشغيل، نسخة Python (يعمل على Termux بدون مكتبات إضافية إن لم تتوفر psutil)
- /cleanup: تنظيف يدوي فوري لمجلد downloads/
- /backup: نسخة احتياطية فورية لقاعدة البيانات
"""

import os
import platform
import shutil
import sys
import time

from telegram import Update
from telegram.ext import ContextTypes

from config import config
from database.models import db
from utils.logger import log_admin_action, get_error_logger
from services.cleanup_service import cleanup_downloads
from services.backup_service import backup_database

error_logger = get_error_logger()

try:
    import psutil
    _HAS_PSUTIL = True
except ImportError:
    _HAS_PSUTIL = False


async def is_admin_check(update: Update) -> bool:
    return await db.is_admin(update.effective_user.id)


def _format_bytes(n: int) -> str:
    for unit in ["B", "KB", "MB", "GB", "TB"]:
        if n < 1024:
            return f"{n:.1f} {unit}"
        n /= 1024
    return f"{n:.1f} PB"


def _format_uptime(seconds: float) -> str:
    seconds = int(seconds)
    h, rem = divmod(seconds, 3600)
    m, s = divmod(rem, 60)
    d, h = divmod(h, 24)
    if d:
        return f"{d}ي {h}س {m}د"
    if h:
        return f"{h}س {m}د"
    return f"{m}د {s}ث"


async def cmd_health(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """عرض صحة النظام: CPU, RAM, Disk, Uptime, Python version - للأدمن فقط"""
    if not await is_admin_check(update):
        await update.message.reply_text("🚫 <b>هذا الأمر للأدمن فقط.</b>", parse_mode="HTML")
        return

    from handlers.status import get_start_time

    uptime = _format_uptime(time.time() - get_start_time())
    python_version = platform.python_version()
    system_info = f"{platform.system()} {platform.release()}"

    if _HAS_PSUTIL:
        try:
            cpu_percent = psutil.cpu_percent(interval=0.5)
            mem = psutil.virtual_memory()
            ram_line = (
                f"{_format_bytes(mem.used)} / {_format_bytes(mem.total)} "
                f"({mem.percent}%)"
            )
            cpu_line = f"{cpu_percent}%"
        except Exception as e:
            cpu_line = ram_line = f"❌ خطأ: {e}"
    else:
        cpu_line = "غير متوفر (مكتبة psutil غير مثبّتة)"
        ram_line = "غير متوفر (مكتبة psutil غير مثبّتة)"

    try:
        total, used, free = shutil.disk_usage(".")
        disk_line = f"{_format_bytes(used)} / {_format_bytes(total)} (متاح: {_format_bytes(free)})"
    except Exception as e:
        disk_line = f"❌ خطأ: {e}"

    text = (
        "🩺 <b>صحة النظام</b>\n\n"
        f"• مدة التشغيل: {uptime}\n"
        f"• نظام التشغيل: {system_info}\n"
        f"• إصدار Python: {python_version}\n\n"
        f"🧮 <b>المعالج (CPU):</b> {cpu_line}\n"
        f"🧠 <b>الذاكرة (RAM):</b> {ram_line}\n"
        f"💾 <b>التخزين:</b> {disk_line}"
    )

    if not _HAS_PSUTIL:
        text += (
            "\n\n💡 لعرض تفاصيل CPU/RAM الدقيقة، ثبّت مكتبة psutil:\n"
            "<code>pip install psutil</code>"
        )

    await update.message.reply_text(text, parse_mode="HTML")


async def cmd_cleanup(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """تنظيف يدوي فوري لمجلد downloads/ - للأدمن فقط"""
    if not await is_admin_check(update):
        await update.message.reply_text("🚫 <b>هذا الأمر للأدمن فقط.</b>", parse_mode="HTML")
        return

    status_msg = await update.message.reply_text("🧹 <b>جاري التنظيف...</b>", parse_mode="HTML")

    try:
        # استيراد مؤجَّل لتجنب أي حلقة استيراد دائرية
        from handlers.download import _locally_active_files

        result = cleanup_downloads(active_files=set(_locally_active_files))
        log_admin_action(
            f"تنظيف يدوي بواسطة {update.effective_user.id}: "
            f"{result['deleted_count']} ملف، {result['deleted_size_mb']:.1f}MB"
        )
        await status_msg.edit_text(
            f"✅ <b>تم التنظيف</b>\n\n"
            f"• ملفات محذوفة: {result['deleted_count']}\n"
            f"• المساحة المُحررة: {result['deleted_size_mb']:.1f}MB\n"
            f"• أخطاء: {result['errors']}",
            parse_mode="HTML",
        )
    except Exception as e:
        error_logger.error(f"فشل التنظيف اليدوي: {e}")
        await status_msg.edit_text(f"❌ <b>فشل التنظيف</b>\n\n{e}", parse_mode="HTML")


async def cmd_backup(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """نسخة احتياطية فورية لقاعدة البيانات - للأدمن فقط"""
    if not await is_admin_check(update):
        await update.message.reply_text("🚫 <b>هذا الأمر للأدمن فقط.</b>", parse_mode="HTML")
        return

    status_msg = await update.message.reply_text(
        "💾 <b>جاري إنشاء نسخة احتياطية...</b>", parse_mode="HTML"
    )

    try:
        result = backup_database()
        if result["success"]:
            log_admin_action(
                f"نسخة احتياطية يدوية بواسطة {update.effective_user.id}: {result['path']}"
            )
            await status_msg.edit_text(
                f"✅ <b>تم إنشاء النسخة الاحتياطية</b>\n\n"
                f"• الملف: <code>{os.path.basename(result['path'])}</code>\n"
                f"• الحجم: {result['size_mb']:.2f}MB",
                parse_mode="HTML",
            )
        else:
            await status_msg.edit_text(
                f"❌ <b>فشل النسخ الاحتياطي</b>\n\n{result['error']}", parse_mode="HTML"
            )
    except Exception as e:
        error_logger.error(f"فشل النسخ الاحتياطي اليدوي: {e}")
        await status_msg.edit_text(f"❌ <b>فشل النسخ الاحتياطي</b>\n\n{e}", parse_mode="HTML")

