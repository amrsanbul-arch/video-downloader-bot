"""
config.py
ملف الإعدادات الرئيسي للبوت - يقرأ المتغيرات من .env
"""

import os
from dotenv import load_dotenv

# تحميل متغيرات البيئة من ملف .env
load_dotenv()


class Config:
    # ===== التوكن والمالك =====
    BOT_TOKEN: str = os.getenv("BOT_TOKEN", "")
    OWNER_ID: int = int(os.getenv("OWNER_ID", "0"))

    # تحويل قائمة الأدمنز من نص إلى أرقام
    _admin_raw = os.getenv("ADMIN_IDS", "")
    ADMIN_IDS: list[int] = [
        int(x.strip()) for x in _admin_raw.split(",") if x.strip().isdigit()
    ]

    # ===== التحميل =====
    MAX_FILE_SIZE_MB: int = int(os.getenv("MAX_FILE_SIZE_MB", "2000"))
    DOWNLOAD_DIR: str = os.getenv("DOWNLOAD_DIR", "downloads")
    DOWNLOAD_TIMEOUT: int = int(os.getenv("DOWNLOAD_TIMEOUT", "300"))

    # ===== قاعدة البيانات =====
    DATABASE_PATH: str = os.getenv("DATABASE_PATH", "database/bot.db")

    # ===== Cookies (لمواقع تطلب تسجيل دخول مثل Reddit/Instagram/TikTok أحيانًا) =====
    COOKIES_FILE: str = os.getenv("COOKIES_FILE", "")

    # ===== Force Subscribe (اختياري) =====
    # ضع اسم القناة بدون @ (مثل: channel_name)
    FORCE_SUBSCRIBE_CHANNEL: str = os.getenv("FORCE_SUBSCRIBE_CHANNEL", "")

    # ===== اسم البوت (يظهر في رسائل "تواصل مع المطور" لتمييزه لو عندك أكتر من بوت) =====
    BOT_DISPLAY_NAME: str = os.getenv("BOT_DISPLAY_NAME", "بوت تحميل الفيديوهات")

    # ===== يوزر المطور على تليجرام (بدون @) =====
    # زرار "تواصل مع المطور" هيفتح شات مباشر مع هذا اليوزر
    OWNER_USERNAME: str = os.getenv("OWNER_USERNAME", "")

    # ===== اللغة =====
    DEFAULT_LANGUAGE: str = os.getenv("DEFAULT_LANGUAGE", "ar")

    # ===== Rate Limit =====
    RATE_LIMIT_MESSAGES: int = int(os.getenv("RATE_LIMIT_MESSAGES", "5"))
    RATE_LIMIT_SECONDS: int = int(os.getenv("RATE_LIMIT_SECONDS", "10"))

    # ===== المواقع المدعومة (لعرضها في /help و /about) =====
    SUPPORTED_SITES = [
        "YouTube", "TikTok", "Facebook", "Instagram", "X (Twitter)",
        "Snapchat", "Reddit", "Pinterest", "Vimeo", "Dailymotion",
    ]

    @classmethod
    def validate(cls):
        """التحقق من وجود الإعدادات الأساسية قبل تشغيل البوت"""
        errors = []
        if not cls.BOT_TOKEN:
            errors.append("BOT_TOKEN غير موجود في ملف .env")
        if cls.OWNER_ID == 0:
            errors.append("OWNER_ID غير موجود أو غير صحيح في ملف .env")

        if errors:
            raise ValueError(
                "❌ أخطاء في الإعدادات:\n" + "\n".join(f"- {e}" for e in errors)
            )

        # التأكد من وجود المجلدات المطلوبة
        os.makedirs(cls.DOWNLOAD_DIR, exist_ok=True)
        os.makedirs("logs", exist_ok=True)
        os.makedirs(os.path.dirname(cls.DATABASE_PATH) or ".", exist_ok=True)

        # تحذير (وليس خطأ يوقف البوت) لو ملف الكوكيز محدد بس غير موجود فعليًا
        if cls.COOKIES_FILE and not os.path.exists(cls.COOKIES_FILE):
            print(
                f"⚠️ تحذير: ملف الكوكيز '{cls.COOKIES_FILE}' محدد في .env "
                f"لكنه غير موجود في المسار. التحميل من مواقع تتطلب تسجيل دخول سيفشل."
            )


config = Config()

