"""
handlers/status.py
أمر /status (للأونر فقط) - عرض حالة شاملة للبوت:
حالة البوت، قاعدة البيانات، الكوكيز، مساحة التخزين، الطابور، التحميلات النشطة
"""

import shutil
import time
from telegram import Update
from telegram.ext import ContextTypes

from config import config
from database.models import db
from utils.cookies_manager import check_all_platforms
from utils.download_tracker import get_status as get_queue_status

_start_time = time.time()


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


def _format_bytes(n: int) -> str:
    for unit in ["B", "KB", "MB", "GB", "TB"]:
        if n < 1024:
            return f"{n:.1f} {unit}"
        n /= 1024
    return f"{n:.1f} PB"


async def cmd_status(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """عرض حالة البوت الشاملة - للأونر فقط (وليس أي أدمن، عمدًا، لحساسية المعلومات)"""
    if update.effective_user.id != config.OWNER_ID:
        await update.message.reply_text("🚫 <b>هذا الأمر للمالك فقط.</b>", parse_mode="HTML")
        return

    # حالة قاعدة البيانات
    try:
        users_count = await db.count_users()
        downloads_count = await db.count_downloads()
        db_status = "✅ متصلة"
    except Exception as e:
        db_status = f"❌ خطأ: {e}"
        users_count = downloads_count = "—"

    # حالة الكوكيز (ملخص سريع)
    try:
        cookie_results = check_all_platforms()
        valid_count = sum(1 for r in cookie_results if r["status"] == "valid")
        total_count = len(cookie_results)
        cookies_summary = f"{valid_count}/{total_count} صالحة"
    except Exception as e:
        cookies_summary = f"❌ خطأ: {e}"

    # مساحة التخزين
    try:
        total, used, free = shutil.disk_usage(".")
        disk_line = f"{_format_bytes(used)} / {_format_bytes(total)} (متاح: {_format_bytes(free)})"
    except Exception as e:
        disk_line = f"❌ خطأ: {e}"

    # حالة الطابور
    try:
        q = get_queue_status()
        queue_line = f"نشطة: {q['active']} / {q['max_concurrent']} | في الانتظار: {q['waiting']}"
    except Exception as e:
        queue_line = f"❌ خطأ: {e}"

    uptime = _format_uptime(time.time() - _start_time)

    text = (
        "📡 <b>حالة البوت</b>\n\n"
        f"• الحالة: ✅ شغال\n"
        f"• مدة التشغيل: {uptime}\n\n"
        f"🗄️ <b>قاعدة البيانات:</b> {db_status}\n"
        f"• المستخدمين: {users_count}\n"
        f"• التحميلات: {downloads_count}\n\n"
        f"🍪 <b>الكوكيز:</b> {cookies_summary}\n\n"
        f"💾 <b>التخزين:</b>\n{disk_line}\n\n"
        f"📥 <b>طابور التحميل:</b>\n{queue_line}"
    )

    await update.message.reply_text(text, parse_mode="HTML")

