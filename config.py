"""
config.py
ملف الإعدادات الرئيسي للبوت - يقرأ المتغيرات من .env
"""

import os
from dotenv import load_dotenv

# تحميل متغيرات البيئة من ملف .env
load_dotenv()


def _safe_int(env_name: str, default: str) -> int:
    """
    قراءة متغير بيئة كرقم صحيح بأمان.
    لو القيمة غير صالحة (مثلاً نص بالغلط)، يتم استخدام القيمة الافتراضية
    بدل ما يكسر تشغيل البوت بالكامل (ValueError) - وده أهم تحسين هنا:
    سابقًا كانت أي قيمة غلط في .env (زي OWNER_ID=Zanos32) توقف البوت بالكامل
    """
    raw = os.getenv(env_name, default)
    try:
        return int(raw)
    except (ValueError, TypeError):
        print(
            f"⚠️ تحذير: قيمة '{env_name}={raw}' في .env غير صحيحة (يجب أن تكون رقم). "
            f"تم استخدام القيمة الافتراضية: {default}"
        )
        return int(default)


class Config:
    # ===== التوكن والمالك =====
    BOT_TOKEN: str = os.getenv("BOT_TOKEN", "")
    OWNER_ID: int = _safe_int("OWNER_ID", "0")

    # تحويل قائمة الأدمنز من نص إلى أرقام
    _admin_raw = os.getenv("ADMIN_IDS", "")
    ADMIN_IDS: list[int] = [
        int(x.strip()) for x in _admin_raw.split(",") if x.strip().isdigit()
    ]

    # ===== التحميل =====
    MAX_FILE_SIZE_MB: int = _safe_int("MAX_FILE_SIZE_MB", "2000")
    DOWNLOAD_DIR: str = os.getenv("DOWNLOAD_DIR", "downloads")
    DOWNLOAD_TIMEOUT: int = _safe_int("DOWNLOAD_TIMEOUT", "300")

    # ===== قاعدة البيانات =====
    DATABASE_PATH: str = os.getenv("DATABASE_PATH", "database/bot.db")

    # ===== Cookies (لمواقع تطلب تسجيل دخول مثل Reddit/Instagram/TikTok أحيانًا) =====
    COOKIES_FILE: str = os.getenv("COOKIES_FILE", "")

    # ===== نظام كوكيز متعدد المنصات =====
    # مجلد فيه ملف كوكيز مستقل لكل منصة: cookies/youtube.txt, cookies/instagram.txt, إلخ
    # لو ملف المنصة غير موجود، يتم الرجوع لـ COOKIES_FILE أعلاه كـ fallback
    COOKIES_DIR: str = os.getenv("COOKIES_DIR", "cookies")

    # ===== استخراج الكوكيز من متصفح سطح المكتب (اختياري) =====
    # يُستخدم فقط على Linux/VPS/Docker (يتم تجاهله تلقائيًا على Termux/Android)
    # القيم المقبولة: chrome, firefox, edge, brave, opera, vivaldi, safari
    # اتركه فاضي لتعطيل هذه الميزة (الوضع الافتراضي على Termux)
    BROWSER_COOKIES_BROWSER: str = os.getenv("BROWSER_COOKIES_BROWSER", "")

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

    # ===== Rate Limit (عام لكل الرسائل) =====
    RATE_LIMIT_MESSAGES: int = _safe_int("RATE_LIMIT_MESSAGES", "5")
    RATE_LIMIT_SECONDS: int = _safe_int("RATE_LIMIT_SECONDS", "10")

    # ===== Rate Limit خاص بالتحميلات فقط =====
    # افتراضيًا: 5 تحميلات لكل مستخدم في الدقيقة
    DOWNLOAD_RATE_LIMIT_COUNT: int = _safe_int("DOWNLOAD_RATE_LIMIT_COUNT", "5")
    DOWNLOAD_RATE_LIMIT_SECONDS: int = _safe_int("DOWNLOAD_RATE_LIMIT_SECONDS", "60")

    # ===== طابور التحميل =====
    # أقصى عدد تحميلات تشتغل في نفس الوقت فعليًا (الباقي ينتظر في الطابور)
    MAX_CONCURRENT_DOWNLOADS: int = _safe_int("MAX_CONCURRENT_DOWNLOADS", "2")
    # حد أقصى إضافي للتحميلات المتزامنة على مستوى السيمافور العام (حماية إضافية من استنزاف الموارد)
    DOWNLOAD_SEMAPHORE_LIMIT: int = _safe_int("DOWNLOAD_SEMAPHORE_LIMIT", "3")

    # ===== تنظيف الملفات المؤقتة تلقائيًا =====
    # حذف أي ملف في downloads/ يكون عمره أكبر من القيمة دي (بالدقايق)، كل ما تشتغل الوظيفة الدورية
    CLEANUP_MAX_AGE_MINUTES: int = _safe_int("CLEANUP_MAX_AGE_MINUTES", "60")
    # كل كام دقيقة تشتغل وظيفة التنظيف التلقائي
    CLEANUP_INTERVAL_MINUTES: int = _safe_int("CLEANUP_INTERVAL_MINUTES", "15")

    # ===== كاش بيانات الفيديو المؤقت (لتقليل طلبات yt-dlp المتكررة) =====
    VIDEO_CACHE_TTL_SECONDS: int = _safe_int("VIDEO_CACHE_TTL_SECONDS", "300")  # 5 دقايق

    # ===== Proxy (اختياري) - يدعم HTTP/HTTPS/SOCKS5 =====
    # مثال: http://user:pass@host:port أو socks5://host:port
    # اتركه فاضي للعمل بدون بروكسي (الوضع الطبيعي)
    PROXY_URL: str = os.getenv("PROXY_URL", "")

    # ===== النسخ الاحتياطي لقاعدة البيانات =====
    BACKUP_DIR: str = os.getenv("BACKUP_DIR", "backups")
    BACKUP_INTERVAL_HOURS: int = _safe_int("BACKUP_INTERVAL_HOURS", "24")
    BACKUP_KEEP_LAST: int = _safe_int("BACKUP_KEEP_LAST", "7")

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
        os.makedirs(cls.COOKIES_DIR, exist_ok=True)
        os.makedirs(cls.BACKUP_DIR, exist_ok=True)
        os.makedirs(os.path.dirname(cls.DATABASE_PATH) or ".", exist_ok=True)

        # تحذير (وليس خطأ يوقف البوت) لو ملف الكوكيز محدد بس غير موجود فعليًا
        if cls.COOKIES_FILE and not os.path.exists(cls.COOKIES_FILE):
            print(
                f"⚠️ تحذير: ملف الكوكيز '{cls.COOKIES_FILE}' محدد في .env "
                f"لكنه غير موجود في المسار. التحميل من مواقع تتطلب تسجيل دخول سيفشل."
            )


config = Config()

