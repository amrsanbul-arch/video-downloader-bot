"""
services/backup_service.py
نسخ احتياطي تلقائي لقاعدة البيانات (SQLite):
- نسخة مضغوطة (.db.gz) في مجلد BACKUP_DIR
- الاحتفاظ بآخر BACKUP_KEEP_LAST نسخة فقط (حذف الأقدم تلقائيًا)
- يعمل دوريًا عبر job_queue، ويدعم استدعاء يدوي من /backup
"""

import os
import gzip
import shutil
import time
from datetime import datetime

from config import config
from utils.logger import logger, get_error_logger

error_logger = get_error_logger()


def backup_database() -> dict:
    """
    إنشاء نسخة احتياطية مضغوطة من قاعدة البيانات الحالية.
    يرجع dict فيه: success, path, size_mb, error
    """
    result = {"success": False, "path": None, "size_mb": 0, "error": None}

    if not os.path.exists(config.DATABASE_PATH):
        result["error"] = "ملف قاعدة البيانات غير موجود"
        return result

    try:
        os.makedirs(config.BACKUP_DIR, exist_ok=True)

        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_filename = f"bot_backup_{timestamp}.db.gz"
        backup_path = os.path.join(config.BACKUP_DIR, backup_filename)

        # نسخ وضغط الملف في خطوة واحدة (بدون نسخة مؤقتة غير مضغوطة بالقرص)
        with open(config.DATABASE_PATH, "rb") as f_in:
            with gzip.open(backup_path, "wb") as f_out:
                shutil.copyfileobj(f_in, f_out)

        size_mb = os.path.getsize(backup_path) / (1024 * 1024)

        result["success"] = True
        result["path"] = backup_path
        result["size_mb"] = size_mb

        logger.info(f"نسخة احتياطية جديدة: {backup_path} ({size_mb:.2f}MB)")

        _cleanup_old_backups()

    except Exception as e:
        result["error"] = str(e)
        error_logger.error(f"فشل إنشاء نسخة احتياطية: {e}")

    return result


def _cleanup_old_backups():
    """حذف أقدم النسخ الاحتياطية، مع الاحتفاظ بآخر BACKUP_KEEP_LAST نسخة فقط"""
    try:
        if not os.path.isdir(config.BACKUP_DIR):
            return

        backups = [
            os.path.join(config.BACKUP_DIR, f)
            for f in os.listdir(config.BACKUP_DIR)
            if f.startswith("bot_backup_") and f.endswith(".db.gz")
        ]
        backups.sort(key=os.path.getmtime, reverse=True)  # الأحدث أولاً

        for old_backup in backups[config.BACKUP_KEEP_LAST:]:
            try:
                os.remove(old_backup)
                logger.info(f"حذف نسخة احتياطية قديمة: {old_backup}")
            except OSError as e:
                error_logger.error(f"فشل حذف نسخة احتياطية قديمة {old_backup}: {e}")

    except Exception as e:
        error_logger.error(f"فشل تنظيف النسخ الاحتياطية القديمة: {e}")


def list_backups() -> list[dict]:
    """قائمة بكل النسخ الاحتياطية الموجودة حاليًا مع تاريخها وحجمها"""
    if not os.path.isdir(config.BACKUP_DIR):
        return []

    backups = []
    for f in sorted(os.listdir(config.BACKUP_DIR), reverse=True):
        if f.startswith("bot_backup_") and f.endswith(".db.gz"):
            path = os.path.join(config.BACKUP_DIR, f)
            backups.append(
                {
                    "name": f,
                    "size_mb": os.path.getsize(path) / (1024 * 1024),
                    "modified": time.ctime(os.path.getmtime(path)),
                }
            )
    return backups


async def backup_job(context) -> None:
    """دالة Job Queue للنسخ الاحتياطي الدوري - لا تتسبب في توقف البوت أبدًا حتى لو فشلت"""
    try:
        result = backup_database()
        if not result["success"]:
            error_logger.warning(f"فشل النسخ الاحتياطي الدوري: {result['error']}")
    except Exception as e:
        error_logger.error(f"فشلت وظيفة النسخ الاحتياطي الدورية بالكامل: {e}")

