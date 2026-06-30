"""
utils/logger.py
نظام تسجيل احترافي - يكتب في ملف logs/bot.log وفي الطرفية في نفس الوقت
"""

import logging
import os
from logging.handlers import RotatingFileHandler

LOG_DIR = "logs"
os.makedirs(LOG_DIR, exist_ok=True)


def setup_logger(name: str = "video_bot") -> logging.Logger:
    logger = logging.getLogger(name)
    logger.setLevel(logging.INFO)

    if logger.handlers:
        # عشان لا نضيف هاندلرز مكررة لو الدالة استُدعيت أكتر من مرة
        return logger

    fmt = logging.Formatter(
        "%(asctime)s | %(levelname)s | %(name)s | %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )

    # كتابة في ملف، مع تدوير الملف عند الوصول لـ 10MB (حتى 5 نسخ احتياطية)
    file_handler = RotatingFileHandler(
        os.path.join(LOG_DIR, "bot.log"),
        maxBytes=10 * 1024 * 1024,
        backupCount=5,
        encoding="utf-8",
    )
    file_handler.setFormatter(fmt)

    # عرض في الطرفية كذلك
    console_handler = logging.StreamHandler()
    console_handler.setFormatter(fmt)

    logger.addHandler(file_handler)
    logger.addHandler(console_handler)

    return logger


def _setup_dedicated_logger(name: str, filename: str, level: int = logging.INFO) -> logging.Logger:
    """
    لوجر منفصل بملفه الخاص (مثل error.log أو download.log)
    إضافي فوق logger الأساسي، ولا يستبدله، حتى لا نكسر أي استخدام حالي لـ `logger`
    """
    dedicated = logging.getLogger(f"video_bot.{name}")
    dedicated.setLevel(level)

    if dedicated.handlers:
        return dedicated

    fmt = logging.Formatter(
        "%(asctime)s | %(levelname)s | %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )

    file_handler = RotatingFileHandler(
        os.path.join(LOG_DIR, filename),
        maxBytes=10 * 1024 * 1024,
        backupCount=5,
        encoding="utf-8",
    )
    file_handler.setFormatter(fmt)
    dedicated.addHandler(file_handler)

    # لا نضيف console_handler هنا لتجنب تكرار نفس الرسالة مرتين في الطرفية
    # (logger الأساسي بيغطي الطرفية بالفعل)
    dedicated.propagate = False

    return dedicated


logger = setup_logger()

# لوجرز إضافية مخصصة - يُستخدمان بجانب logger الأساسي وليس بدلاً منه
error_logger = _setup_dedicated_logger("error", "error.log", level=logging.ERROR)
download_logger = _setup_dedicated_logger("download", "download.log", level=logging.INFO)
admin_logger = _setup_dedicated_logger("admin", "admin.log", level=logging.INFO)
startup_logger = _setup_dedicated_logger("startup", "startup.log", level=logging.INFO)
cleanup_logger = _setup_dedicated_logger("cleanup", "cleanup.log", level=logging.INFO)


def log_error(message: str, exc: Exception = None):
    """تسجيل خطأ في logs/bot.log و logs/error.log معًا، بدون توقف البوت أبدًا"""
    try:
        logger.error(message, exc_info=exc)
        error_logger.error(message, exc_info=exc)
    except Exception:
        # لا نسمح لفشل التسجيل نفسه بإيقاف البوت
        pass


def log_download(message: str):
    """تسجيل نجاح/فشل تحميل في logs/bot.log و logs/download.log معًا"""
    try:
        logger.info(message)
        download_logger.info(message)
    except Exception:
        pass


def log_admin_action(message: str):
    """تسجيل أي إجراء إداري (حظر، برودكاست، نسخ احتياطي، تنظيف يدوي...) في logs/admin.log"""
    try:
        logger.info(f"[ADMIN] {message}")
        admin_logger.info(message)
    except Exception:
        pass


def log_startup(message: str):
    """تسجيل أحداث بدء التشغيل في logs/startup.log"""
    try:
        logger.info(message)
        startup_logger.info(message)
    except Exception:
        pass


def log_cleanup(message: str):
    """تسجيل عمليات تنظيف الملفات/الكاش في logs/cleanup.log"""
    try:
        logger.info(message)
        cleanup_logger.info(message)
    except Exception:
        pass


def get_error_logger() -> logging.Logger:
    """إرجاع لوجر logs/error.log مباشرة (يُستخدم في الموديولز التي تفضّل استدعاء logger.error مباشرة)"""
    return error_logger


def get_download_logger() -> logging.Logger:
    """إرجاع لوجر logs/download.log مباشرة"""
    return download_logger


def get_admin_logger() -> logging.Logger:
    """إرجاع لوجر logs/admin.log مباشرة"""
    return admin_logger

