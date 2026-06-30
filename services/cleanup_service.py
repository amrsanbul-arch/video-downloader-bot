"""
services/cleanup_service.py
تنظيف تلقائي لمجلد downloads/ - يحذف الملفات الأقدم من CLEANUP_MAX_AGE_MINUTES
يُستدعى دوريًا عبر job_queue، ويدعم استدعاء يدوي من /cleanup
لا يحذف أي ملف نشط حاليًا في عملية تحميل (يتم تتبعها عبر utils.download_tracker)
"""

import os
import time
from config import config
from utils.logger import log_cleanup, get_error_logger

error_logger = get_error_logger()


def cleanup_downloads(active_files: set[str] | None = None) -> dict:
    """
    حذف الملفات القديمة في DOWNLOAD_DIR.
    active_files: مسارات الملفات الجاري تحميلها/رفعها حاليًا (لا تُحذف أبدًا)
    يرجع dict فيه: deleted_count, deleted_size_mb, errors
    """
    active_files = active_files or set()
    max_age_seconds = config.CLEANUP_MAX_AGE_MINUTES * 60
    now = time.time()

    deleted_count = 0
    deleted_size = 0
    errors = 0

    if not os.path.isdir(config.DOWNLOAD_DIR):
        return {"deleted_count": 0, "deleted_size_mb": 0, "errors": 0}

    for filename in os.listdir(config.DOWNLOAD_DIR):
        if filename == ".gitkeep":
            continue

        path = os.path.join(config.DOWNLOAD_DIR, filename)

        if path in active_files:
            continue  # ملف قيد الاستخدام حاليًا - لا يُحذف أبدًا

        try:
            if not os.path.isfile(path):
                continue

            file_age = now - os.path.getmtime(path)
            if file_age > max_age_seconds:
                size = os.path.getsize(path)
                os.remove(path)
                deleted_count += 1
                deleted_size += size
                log_cleanup(f"تم حذف ملف قديم: {filename} (عمره {file_age/60:.0f} دقيقة)")

        except Exception as e:
            errors += 1
            error_logger.error(f"فشل حذف الملف {path} أثناء التنظيف التلقائي: {e}")

    deleted_size_mb = deleted_size / (1024 * 1024)

    if deleted_count > 0:
        log_cleanup(
            f"انتهى التنظيف: حُذف {deleted_count} ملف، إجمالي {deleted_size_mb:.1f}MB"
        )

    return {
        "deleted_count": deleted_count,
        "deleted_size_mb": deleted_size_mb,
        "errors": errors,
    }


async def cleanup_job(context) -> None:
    """
    دالة Job Queue (تُستدعى دوريًا من Application.job_queue تلقائيًا)
    لا تتسبب في توقف البوت أبدًا حتى لو فشلت
    """
    try:
        # استيراد مؤجَّل لتجنب أي حلقة استيراد دائرية بين الموديولز
        from handlers.download import _locally_active_files

        result = cleanup_downloads(active_files=set(_locally_active_files))
        if result["errors"] > 0:
            error_logger.warning(f"التنظيف التلقائي انتهى مع {result['errors']} أخطاء")
    except Exception as e:
        error_logger.error(f"فشلت وظيفة التنظيف الدورية بالكامل: {e}")

