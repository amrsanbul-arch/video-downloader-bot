#!/data/data/com.termux/files/usr/bin/bash
# production_readiness_update.sh
set -e
echo "🔧 تطبيق تحسينات الاستقرار والجاهزية للإنتاج..."

mkdir -p cookies logs downloads
touch cookies/.gitkeep

mkdir -p $(dirname 'config.py')
cat > 'config.py' << 'ZEOF_MARKER_UNIQUE'
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

    # ===== نظام كوكيز متعدد المنصات (جديد) =====
    # مجلد فيه ملف كوكيز مستقل لكل منصة: cookies/youtube.txt, cookies/instagram.txt, إلخ
    # لو ملف المنصة غير موجود، يتم الرجوع لـ COOKIES_FILE أعلاه كـ fallback
    COOKIES_DIR: str = os.getenv("COOKIES_DIR", "cookies")

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
    RATE_LIMIT_MESSAGES: int = int(os.getenv("RATE_LIMIT_MESSAGES", "5"))
    RATE_LIMIT_SECONDS: int = int(os.getenv("RATE_LIMIT_SECONDS", "10"))

    # ===== Rate Limit خاص بالتحميلات فقط (جديد) =====
    # افتراضيًا: 5 تحميلات لكل مستخدم في الدقيقة
    DOWNLOAD_RATE_LIMIT_COUNT: int = int(os.getenv("DOWNLOAD_RATE_LIMIT_COUNT", "5"))
    DOWNLOAD_RATE_LIMIT_SECONDS: int = int(os.getenv("DOWNLOAD_RATE_LIMIT_SECONDS", "60"))

    # ===== طابور التحميل (جديد) =====
    # أقصى عدد تحميلات تشتغل في نفس الوقت فعليًا (الباقي ينتظر في الطابور)
    MAX_CONCURRENT_DOWNLOADS: int = int(os.getenv("MAX_CONCURRENT_DOWNLOADS", "2"))

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
        os.makedirs(os.path.dirname(cls.DATABASE_PATH) or ".", exist_ok=True)

        # تحذير (وليس خطأ يوقف البوت) لو ملف الكوكيز محدد بس غير موجود فعليًا
        if cls.COOKIES_FILE and not os.path.exists(cls.COOKIES_FILE):
            print(
                f"⚠️ تحذير: ملف الكوكيز '{cls.COOKIES_FILE}' محدد في .env "
                f"لكنه غير موجود في المسار. التحميل من مواقع تتطلب تسجيل دخول سيفشل."
            )


config = Config()

ZEOF_MARKER_UNIQUE
echo "✅ تم تحديث config.py"

mkdir -p $(dirname '.env.example')
cat > '.env.example' << 'ZEOF_MARKER_UNIQUE'
# ===== إعدادات البوت الأساسية =====
BOT_TOKEN=ضع_التوكن_هنا

# آي دي الأونر (المالك) - رقم تليجرام بتاعك
OWNER_ID=123456789

# آي ديز المشرفين، مفصولة بفاصلة (اختياري)
ADMIN_IDS=

# ===== إعدادات التحميل =====
MAX_FILE_SIZE_MB=2000
DOWNLOAD_DIR=downloads
DOWNLOAD_TIMEOUT=300

# ===== إعدادات قاعدة البيانات =====
DATABASE_PATH=database/bot.db

# مسار ملف الكوكيز العام (اختياري) - يُستخدم كـ fallback لو ملف المنصة المخصص
# (في مجلد cookies/) غير موجود أو منتهي الصلاحية
COOKIES_FILE=

# مجلد ملفات الكوكيز المخصصة لكل منصة (cookies/youtube.txt, instagram.txt, tiktok.txt)
COOKIES_DIR=cookies

# ===== Force Subscribe (اختياري) =====
# اسم القناة بدون @ لو تبي تفرض اشتراك على المستخدمين قبل التحميل
# مثل: my_channel أو اتركه فاضي للتعطيل
FORCE_SUBSCRIBE_CHANNEL=

# اسم البوت يظهر في رسائل "تواصل مع المطور" (مفيد لو شغال عدة بوتات بنفس حساب المطور)
BOT_DISPLAY_NAME=بوت تحميل الفيديوهات

# يوزرك على تليجرام بدون @ (مثل: amrsanbul)
# زرار "تواصل مع المطور" هيفتح شات مباشر معاك بدالة هذا اليوزر
OWNER_USERNAME=

# ===== إعدادات اللغة =====
DEFAULT_LANGUAGE=ar

# ===== Rate Limit (عام لكل الرسائل) =====
RATE_LIMIT_MESSAGES=5
RATE_LIMIT_SECONDS=10

# ===== Rate Limit خاص بالتحميلات فقط (5 تحميلات لكل مستخدم في الدقيقة) =====
DOWNLOAD_RATE_LIMIT_COUNT=5
DOWNLOAD_RATE_LIMIT_SECONDS=60

# ===== طابور التحميل: أقصى عدد تحميلات تشتغل في نفس الوقت =====
MAX_CONCURRENT_DOWNLOADS=2

ZEOF_MARKER_UNIQUE
echo "✅ تم تحديث .env.example"

mkdir -p $(dirname '.gitignore')
cat > '.gitignore' << 'ZEOF_MARKER_UNIQUE'
.env
cookies.txt
*.cookies.txt
cookies/*.txt
!cookies/.gitkeep
__pycache__/
*.pyc
*.pyo
*.db
*.sqlite3
downloads/*
!downloads/.gitkeep
logs/*.log
.venv/
venv/
*.log
.DS_Store

ZEOF_MARKER_UNIQUE
echo "✅ تم تحديث .gitignore"

mkdir -p $(dirname 'bot.py')
cat > 'bot.py' << 'ZEOF_MARKER_UNIQUE'
"""
bot.py - النسخة 2.4
- لوحة إدارة كاملة
- اختيار جودة دقيقة + جودة افتراضية
- Force Subscribe
- شريط تقدم
- قائمة أزرار ثابتة موسّعة
- زرار "تواصل مع المطور" يفتح شات تليجرام مباشر
"""

from telegram import Update
from telegram.ext import (
    Application,
    CommandHandler,
    MessageHandler,
    CallbackQueryHandler,
    ContextTypes,
    filters,
)

from config import config
from database.models import db
from utils.logger import logger

from handlers import start, help as help_handler, settings, admin, download
from handlers import admin_dashboard, force_subscribe, menu, cookies, status


async def on_error(update: object, context: ContextTypes.DEFAULT_TYPE):
    logger.error(f"حدث خطأ غير متوقع: {context.error}", exc_info=context.error)


async def post_init(application: Application):
    await db.connect()
    logger.info("✅ تم الاتصال بقاعدة البيانات بنجاح")


async def post_shutdown(application: Application):
    await db.close()
    logger.info("🔌 تم إغلاق الاتصال بقاعدة البيانات")


async def cmd_cancel(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """إلغاء أي عملية معلّقة (برودكاست/حظر من جانب الأدمن)"""
    context.user_data.pop("admin_action", None)
    await update.message.reply_text("✅ <b>تم الإلغاء.</b>", parse_mode="HTML")


def main():
    config.validate()
    logger.info("🚀 بدء تشغيل البوت...")

    app = (
        Application.builder()
        .token(config.BOT_TOKEN)
        .connect_timeout(30)
        .read_timeout(30)
        .write_timeout(30)
        .pool_timeout(30)
        .post_init(post_init)
        .post_shutdown(post_shutdown)
        .build()
    )

    # ===== أوامر عامة =====
    app.add_handler(CommandHandler("start", start.cmd_start))
    app.add_handler(CommandHandler("about", start.cmd_about))
    app.add_handler(CommandHandler("ping", start.cmd_ping))
    app.add_handler(CommandHandler("lang", start.cmd_lang))
    app.add_handler(CommandHandler("cancel", cmd_cancel))
    app.add_handler(CallbackQueryHandler(start.on_lang_callback, pattern="^setlang_"))

    app.add_handler(CommandHandler("help", help_handler.cmd_help))

    app.add_handler(CommandHandler("settings", settings.cmd_settings))
    app.add_handler(CommandHandler("stats", settings.cmd_stats))

    # ===== أوامر الإدارة (القديمة) =====
    app.add_handler(CommandHandler("users", admin.cmd_users))
    app.add_handler(CommandHandler("botstats", admin.cmd_botstats))
    app.add_handler(CommandHandler("ban", admin.cmd_ban))
    app.add_handler(CommandHandler("unban", admin.cmd_unban))
    app.add_handler(CommandHandler("broadcast", admin.cmd_broadcast))
    app.add_handler(CommandHandler("logs", admin.cmd_logs))
    app.add_handler(CommandHandler("restart", admin.cmd_restart))
    app.add_handler(CommandHandler("update", admin.cmd_update))

    # ===== لوحة الإدارة الجديدة =====
    app.add_handler(CommandHandler("admin", admin_dashboard.cmd_admin))
    app.add_handler(
        CallbackQueryHandler(admin_dashboard.on_admin_callback, pattern="^admin_")
    )

    # ===== الجودة الافتراضية =====
    app.add_handler(CallbackQueryHandler(menu.on_quality_callback, pattern="^setq_"))

    # ===== إدارة الكوكيز (أدمن) =====
    app.add_handler(CommandHandler("check_cookies", cookies.cmd_check_cookies))
    app.add_handler(CommandHandler("update_cookies", cookies.cmd_update_cookies))
    app.add_handler(
        CallbackQueryHandler(cookies.on_cookie_site_callback, pattern="^cksite_")
    )
    app.add_handler(MessageHandler(filters.Document.ALL, cookies.on_cookie_document))

    # ===== حالة البوت (أونر فقط) =====
    app.add_handler(CommandHandler("status", status.cmd_status))

    # ===== معالج نصوص موحّد =====
    async def on_text_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
        # 1. ضغطة على زر من القائمة الثابتة؟
        if await menu.is_menu_button(update):
            await menu.handle_menu_button(update, context)
            return

        # 2. الأدمن وسط عملية (برودكاست/حظر)؟
        pending_action = context.user_data.get("admin_action")
        if pending_action and await admin_dashboard.is_admin_check(update):
            await admin_dashboard.on_admin_text_input(update, context)
            return

        # 3. التحقق من Force Subscribe
        if not await force_subscribe.check_subscription(update, context):
            await force_subscribe.send_subscribe_message(update, context)
            return

        # 4. معالجة كرابط فيديو عادي
        await download.on_message(update, context)

    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, on_text_message))
    app.add_handler(CallbackQueryHandler(download.on_download_callback, pattern="^dl"))

    # ===== معالجة الأخطاء =====
    app.add_error_handler(on_error)

    logger.info("✅ البوت شغال دلوقتي...")
    app.run_polling(allowed_updates=Update.ALL_TYPES)


if __name__ == "__main__":
    main()

ZEOF_MARKER_UNIQUE
echo "✅ تم تحديث bot.py"

mkdir -p $(dirname 'utils/logger.py')
cat > 'utils/logger.py' << 'ZEOF_MARKER_UNIQUE'
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

    # كتابة في ملف، مع تدوير الملف عند الوصول لـ 5MB (حتى 5 نسخ احتياطية)
    file_handler = RotatingFileHandler(
        os.path.join(LOG_DIR, "bot.log"),
        maxBytes=5 * 1024 * 1024,
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
        maxBytes=5 * 1024 * 1024,
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


def get_error_logger() -> logging.Logger:
    """إرجاع لوجر logs/error.log مباشرة (يُستخدم في الموديولز التي تفضّل استدعاء logger.error مباشرة)"""
    return error_logger


def get_download_logger() -> logging.Logger:
    """إرجاع لوجر logs/download.log مباشرة"""
    return download_logger

ZEOF_MARKER_UNIQUE
echo "✅ تم تحديث utils/logger.py"

mkdir -p $(dirname 'utils/helpers.py')
cat > 'utils/helpers.py' << 'ZEOF_MARKER_UNIQUE'
"""
utils/helpers.py
دوال مساعدة عامة: تنسيق الحجم والمدة، ونظام Rate Limit بسيط في الذاكرة
"""

import time
from collections import defaultdict
from config import config


def format_size(num_bytes: float) -> str:
    """تحويل الحجم من بايت إلى صيغة مقروءة (KB, MB, GB)"""
    if not num_bytes:
        return "غير معروف"
    for unit in ["B", "KB", "MB", "GB"]:
        if num_bytes < 1024:
            return f"{num_bytes:.1f} {unit}"
        num_bytes /= 1024
    return f"{num_bytes:.1f} TB"


def format_duration(seconds: float) -> str:
    """تحويل المدة بالثواني إلى صيغة دقايق:ثواني أو ساعات:دقايق:ثواني"""
    if not seconds:
        return "غير معروف"
    seconds = int(seconds)
    h, rem = divmod(seconds, 3600)
    m, s = divmod(rem, 60)
    if h:
        return f"{h:02d}:{m:02d}:{s:02d}"
    return f"{m:02d}:{s:02d}"


class RateLimiter:
    """
    نظام Rate Limit بسيط في الذاكرة:
    يمنع المستخدم من إرسال أكتر من X رسالة كل Y ثانية
    """

    def __init__(self, max_messages: int = None, window_seconds: int = None):
        self.max_messages = max_messages or config.RATE_LIMIT_MESSAGES
        self.window_seconds = window_seconds or config.RATE_LIMIT_SECONDS
        self._hits: dict[int, list[float]] = defaultdict(list)

    def is_allowed(self, user_id: int) -> bool:
        now = time.time()
        window_start = now - self.window_seconds

        # شيل الطلبات القديمة الخارجة عن النافذة الزمنية
        self._hits[user_id] = [t for t in self._hits[user_id] if t > window_start]

        if len(self._hits[user_id]) >= self.max_messages:
            return False

        self._hits[user_id].append(now)
        return True


rate_limiter = RateLimiter()

# Rate limiter مستقل خاص بالتحميلات فقط (افتراضيًا: 5 تحميلات/دقيقة لكل مستخدم)
# مستقل عن rate_limiter العام أعلاه (اللي بيحكم كل الرسائل النصية)
download_rate_limiter = RateLimiter(
    max_messages=config.DOWNLOAD_RATE_LIMIT_COUNT,
    window_seconds=config.DOWNLOAD_RATE_LIMIT_SECONDS,
)

ZEOF_MARKER_UNIQUE
echo "✅ تم تحديث utils/helpers.py"

mkdir -p $(dirname 'utils/cookies_manager.py')
cat > 'utils/cookies_manager.py' << 'ZEOF_MARKER_UNIQUE'
"""
utils/cookies_manager.py
نظام كوكيز متعدد المنصات:
- كل منصة لها ملف كوكيز مستقل في مجلد cookies/
- فحص الحالة (موجود/مفقود/منتهي) بدون أي اتصال بالإنترنت (فحص محلي فقط)
- Fallback تلقائي على COOKIES_FILE القديم لو ملف المنصة غير موجود
"""

import os
import time

from config import config
from utils.logger import logger

# ربط اسم المنصة (نفس الأسماء التي يرجعها detect_site) بملف الكوكيز المتوقع
PLATFORM_FILES = {
    "YouTube": "youtube.txt",
    "TikTok": "tiktok.txt",
    "Facebook": "facebook.txt",
    "Instagram": "instagram.txt",
    "X (Twitter)": "twitter.txt",
    "Snapchat": "snapchat.txt",
    "Reddit": "reddit.txt",
    "Pinterest": "pinterest.txt",
    "Vimeo": "vimeo.txt",
    "Dailymotion": "dailymotion.txt",
}


def get_cookie_path(site: str) -> str | None:
    """
    إرجاع مسار ملف الكوكيز الخاص بالمنصة لو موجود فعليًا،
    أو COOKIES_FILE القديم كـ fallback، أو None لو لا يوجد أي منهما
    """
    filename = PLATFORM_FILES.get(site)
    if filename:
        platform_path = os.path.join(config.COOKIES_DIR, filename)
        if os.path.exists(platform_path) and os.path.getsize(platform_path) > 0:
            return platform_path

    # Fallback لملف الكوكيز العام القديم (للتوافق مع الإعدادات السابقة)
    if config.COOKIES_FILE and os.path.exists(config.COOKIES_FILE):
        return config.COOKIES_FILE

    return None


def get_cookie_path_for_url(url: str) -> str | None:
    """نفس get_cookie_path لكن باستخدام الرابط مباشرة (يحدد المنصة تلقائيًا)"""
    from utils.validators import detect_site  # استيراد محلي لتجنب أي حلقة استيراد

    site = detect_site(url)
    return get_cookie_path(site)


def _check_single_file_status(path: str) -> str:
    """
    فحص محلي (بدون إنترنت) لحالة ملف كوكيز واحد بصيغة Netscape:
    يرجع: 'missing' / 'empty' / 'expired' / 'valid'
    """
    if not path or not os.path.exists(path):
        return "missing"

    try:
        if os.path.getsize(path) == 0:
            return "empty"

        now = time.time()
        has_any_cookie = False
        has_future_expiry = False

        with open(path, "r", encoding="utf-8", errors="ignore") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                parts = line.split("\t")
                if len(parts) < 7:
                    continue
                has_any_cookie = True
                try:
                    expiry = float(parts[4])
                except (ValueError, IndexError):
                    expiry = 0
                # expiry == 0 يعني كوكي جلسة (بدون تاريخ انتهاء محدد) - نعتبرها صالحة
                if expiry == 0 or expiry > now:
                    has_future_expiry = True

        if not has_any_cookie:
            return "empty"
        return "valid" if has_future_expiry else "expired"

    except Exception as e:
        logger.warning(f"فشل فحص ملف الكوكيز {path}: {e}")
        return "missing"


def check_platform_status(site: str) -> dict:
    """فحص حالة الكوكيز لمنصة واحدة، يرجع dict فيها الحالة والمسار"""
    filename = PLATFORM_FILES.get(site)
    platform_path = os.path.join(config.COOKIES_DIR, filename) if filename else None

    status = "missing"
    used_path = None

    if platform_path and os.path.exists(platform_path):
        status = _check_single_file_status(platform_path)
        used_path = platform_path
    elif config.COOKIES_FILE and os.path.exists(config.COOKIES_FILE):
        status = _check_single_file_status(config.COOKIES_FILE)
        used_path = config.COOKIES_FILE + " (fallback عام)"

    return {"site": site, "status": status, "path": used_path}


def check_all_platforms() -> list[dict]:
    """فحص حالة الكوكيز لكل المنصات المعروفة دفعة واحدة"""
    results = []
    for site in PLATFORM_FILES:
        try:
            results.append(check_platform_status(site))
        except Exception as e:
            logger.warning(f"فشل فحص كوكيز {site}: {e}")
            results.append({"site": site, "status": "missing", "path": None})
    return results


def save_cookie_file(site: str, content: bytes) -> str | None:
    """
    حفظ محتوى ملف كوكيز جديد لمنصة معينة في مجلد cookies/
    يرجع المسار النهائي، أو None لو المنصة غير معروفة
    """
    filename = PLATFORM_FILES.get(site)
    if not filename:
        return None

    os.makedirs(config.COOKIES_DIR, exist_ok=True)
    path = os.path.join(config.COOKIES_DIR, filename)

    with open(path, "wb") as f:
        f.write(content)

    return path

ZEOF_MARKER_UNIQUE
echo "✅ تم تحديث utils/cookies_manager.py"

mkdir -p $(dirname 'utils/download_tracker.py')
cat > 'utils/download_tracker.py' << 'ZEOF_MARKER_UNIQUE'
"""
utils/download_tracker.py
طابور تحميل بسيط: يحدد أقصى عدد تحميلات تشتغل في نفس الوقت فعليًا (Semaphore)
+ عدّادات بسيطة لمعرفة عدد التحميلات النشطة والمنتظرة (تُستخدم في /status)
"""

import asyncio
from contextlib import asynccontextmanager

from config import config

_semaphore = asyncio.Semaphore(config.MAX_CONCURRENT_DOWNLOADS)

_active_count = 0
_waiting_count = 0


@asynccontextmanager
async def download_slot():
    """
    Context manager: ينتظر في الطابور لو التحميلات الحالية وصلت للحد الأقصى،
    ثم يحجز "سلوت" تحميل، ويحرره تلقائيًا في النهاية حتى لو حصل استثناء (finally)
    """
    global _active_count, _waiting_count

    _waiting_count += 1
    acquired = False
    try:
        await _semaphore.acquire()
        acquired = True
        _waiting_count -= 1
        _active_count += 1
        yield
    finally:
        if acquired:
            _active_count -= 1
            _semaphore.release()
        else:
            _waiting_count -= 1


def get_status() -> dict:
    """إرجاع حالة الطابور الحالية - يُستخدم في أمر /status"""
    return {
        "active": _active_count,
        "waiting": _waiting_count,
        "max_concurrent": config.MAX_CONCURRENT_DOWNLOADS,
    }

ZEOF_MARKER_UNIQUE
echo "✅ تم تحديث utils/download_tracker.py"

mkdir -p $(dirname 'services/audio.py')
cat > 'services/audio.py' << 'ZEOF_MARKER_UNIQUE'
"""
services/audio.py
استخراج الصوت بصيغة MP3 من الفيديو باستخدام yt-dlp + ffmpeg
"""

import os
import uuid
import asyncio
import yt_dlp

from config import config
from utils.cookies_manager import get_cookie_path

DOWNLOAD_DIR = config.DOWNLOAD_DIR


def _download_audio_sync(url: str, out_template: str, site: str = None) -> None:
    opts = {
        "outtmpl": out_template,
        "format": "bestaudio/best",
        "quiet": True,
        "no_warnings": True,
        "noplaylist": True,
        "socket_timeout": config.DOWNLOAD_TIMEOUT,
        "postprocessors": [
            {
                "key": "FFmpegExtractAudio",
                "preferredcodec": "mp3",
                "preferredquality": "192",
            }
        ],
    }
    cookie_path = get_cookie_path(site) if site else (config.COOKIES_FILE or None)
    if cookie_path:
        opts["cookiefile"] = cookie_path
    with yt_dlp.YoutubeDL(opts) as ydl:
        ydl.download([url])


async def download_audio(url: str) -> str:
    """
    استخراج الصوت من الرابط وتحويله إلى MP3
    يرجع مسار ملف MP3 النهائي
    """
    from utils.validators import detect_site

    site = detect_site(url)
    file_id = uuid.uuid4().hex[:10]
    out_template = os.path.join(DOWNLOAD_DIR, f"{file_id}.%(ext)s")

    loop = asyncio.get_event_loop()
    await loop.run_in_executor(None, _download_audio_sync, url, out_template, site)

    expected_path = os.path.join(DOWNLOAD_DIR, f"{file_id}.mp3")
    if os.path.exists(expected_path):
        return expected_path

    # fallback لو الامتداد اختلف لأي سبب
    for f in os.listdir(DOWNLOAD_DIR):
        if f.startswith(file_id):
            return os.path.join(DOWNLOAD_DIR, f)

    raise FileNotFoundError("فشل استخراج الصوت - لم يتم العثور على الملف الناتج")

ZEOF_MARKER_UNIQUE
echo "✅ تم تحديث services/audio.py"

mkdir -p $(dirname 'services/downloader.py')
cat > 'services/downloader.py' << 'ZEOF_MARKER_UNIQUE'
"""
services/downloader.py
الخدمة الأساسية للتحميل عبر yt-dlp - تحليل الرابط، استخراج المعلومات، وتحميل الفيديو/الصوت
"""

import os
import uuid
import asyncio
import yt_dlp

from config import config
from utils.cookies_manager import get_cookie_path

DOWNLOAD_DIR = config.DOWNLOAD_DIR


def _build_ydl_opts(out_path: str, fmt: str = "best", site: str = None) -> dict:
    """إعدادات yt-dlp الأساسية المشتركة"""
    opts = {
        "outtmpl": out_path,
        "format": fmt,
        "quiet": True,
        "no_warnings": True,
        "noplaylist": True,
        "merge_output_format": "mp4",
        "socket_timeout": config.DOWNLOAD_TIMEOUT,
    }
    cookie_path = get_cookie_path(site) if site else (config.COOKIES_FILE or None)
    if cookie_path:
        opts["cookiefile"] = cookie_path
    return opts


def _extract_info_sync(url: str, site: str = None) -> dict:
    """استخراج معلومات الفيديو بدون تحميل (تشغيل sync داخل thread)"""
    opts = {
        "quiet": True,
        "no_warnings": True,
        "noplaylist": True,
        "skip_download": True,
    }
    cookie_path = get_cookie_path(site) if site else (config.COOKIES_FILE or None)
    if cookie_path:
        opts["cookiefile"] = cookie_path
    with yt_dlp.YoutubeDL(opts) as ydl:
        info = ydl.extract_info(url, download=False)
        return info


async def get_video_info(url: str) -> dict:
    """
    إرجاع معلومات الفيديو الأساسية: العنوان، المدة، الحجم التقريبي، الصورة المصغرة
    """
    from utils.validators import detect_site  # استيراد محلي لتجنب أي حلقة استيراد

    site = detect_site(url)
    loop = asyncio.get_event_loop()
    info = await loop.run_in_executor(None, _extract_info_sync, url, site)

    # تقدير الحجم لأعلى جودة متاحة
    filesize = info.get("filesize") or info.get("filesize_approx")
    if not filesize:
        formats = info.get("formats", [])
        sizes = [f.get("filesize") or f.get("filesize_approx") for f in formats]
        sizes = [s for s in sizes if s]
        filesize = max(sizes) if sizes else 0

    return {
        "id": info.get("id"),
        "title": info.get("title", "بدون عنوان"),
        "duration": info.get("duration", 0),
        "filesize": filesize,
        "thumbnail": info.get("thumbnail"),
        "webpage_url": info.get("webpage_url", url),
        "extractor": info.get("extractor_key", "Unknown"),
        "uploader": info.get("uploader") or info.get("channel") or "—",
        "abr": info.get("abr") or 128,
        "height": info.get("height") or 0,
    }


def _download_sync(url: str, out_path: str, fmt: str, height: int = None, site: str = None) -> str:
    opts = _build_ydl_opts(out_path, fmt, site)
    if height:
        opts["format"] = f"bestvideo[height<={height}]+bestaudio/best[height<={height}]/best"
    with yt_dlp.YoutubeDL(opts) as ydl:
        ydl.download([url])
    return out_path


async def download_video(url: str, quality: str = "high", height: int = None) -> str:
    """
    تحميل الفيديو بجودة معينة:
    quality: 'high', 'medium', أو 'custom'
    height: الارتفاع بالبكسل (480, 720, 1080, 2160)
    يرجع مسار الملف النهائي
    """
    from utils.validators import detect_site

    site = detect_site(url)
    file_id = uuid.uuid4().hex[:10]
    out_template = os.path.join(DOWNLOAD_DIR, f"{file_id}.%(ext)s")

    # إذا حددوا ارتفاع محدد
    if height:
        fmt = f"bestvideo[height<={height}]+bestaudio/best[height<={height}]/best"
    elif quality == "medium":
        fmt = "bestvideo[height<=480]+bestaudio/best[height<=480]/best"
    elif quality == "custom":
        fmt = "best"
    else:  # high
        fmt = "bestvideo[height<=1080]+bestaudio/best[height<=1080]/best"

    loop = asyncio.get_event_loop()
    await loop.run_in_executor(None, _download_sync, url, out_template, fmt, height, site)

    # تحديد المسار النهائي الحقيقي بعد التحميل (الامتداد قد يتغير)
    for f in os.listdir(DOWNLOAD_DIR):
        if f.startswith(file_id):
            return os.path.join(DOWNLOAD_DIR, f)

    raise FileNotFoundError("فشل تحميل الفيديو - لم يتم العثور على الملف الناتج")


async def get_quality_estimates(url: str) -> dict:
    """
    إرجاع قاموس {height: estimated_filesize_bytes} لكل جودة متاحة فعليًا للفيديو
    """
    from utils.validators import detect_site

    site = detect_site(url)
    loop = asyncio.get_event_loop()
    info = await loop.run_in_executor(None, _extract_info_sync, url, site)

    formats = info.get("formats", [])
    estimates: dict[int, int] = {}

    for fmt in formats:
        height = fmt.get("height")
        if not height:
            continue
        size = fmt.get("filesize") or fmt.get("filesize_approx") or 0
        if size and (height not in estimates or size > estimates[height]):
            estimates[height] = size

    return estimates


def cleanup_file(path: str):
    """حذف الملف المؤقت بعد إرساله للمستخدم"""
    try:
        if path and os.path.exists(path):
            os.remove(path)
    except OSError:
        pass

ZEOF_MARKER_UNIQUE
echo "✅ تم تحديث services/downloader.py"

mkdir -p $(dirname 'handlers/download.py')
cat > 'handlers/download.py' << 'ZEOF_MARKER_UNIQUE'
"""
handlers/download.py
استقبال الروابط، تحليل مفصّل، شبكة جودات كاملة (144p → 1080p + Best)
"""

import uuid
import html
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import ContextTypes

from config import config
from database.models import db
from utils.logger import logger, get_download_logger
from utils.i18n import t
from utils.validators import is_valid_url, detect_site, extract_first_url
from utils.helpers import rate_limiter, download_rate_limiter, format_duration
from services.downloader import (
    get_video_info,
    get_quality_estimates,
    download_video,
    cleanup_file,
)
from services.audio import download_audio
from services.thumbnail import download_thumbnail
from utils.download_tracker import download_slot
from handlers.menu import get_default_quality

download_logger = get_download_logger()

_pending_urls: dict[str, str] = {}

QUALITY_GRID = [144, 240, 360, 480, 720, 1080]


async def get_lang(user_id: int) -> str:
    return await db.get_user_language(user_id)


def _kb_str(size_bytes: int) -> str:
    """تنسيق الحجم بالكيلوبايت/ميجابايت بدقّة عشرية (لمطابقة ستايل التحليل)"""
    if not size_bytes:
        return "—"
    kb = size_bytes / 1024
    if kb < 1024:
        return f"{kb:.2f} KB"
    return f"{kb / 1024:.2f} MB"


def _build_analysis_caption(info: dict, site: str, estimates: dict) -> str:
    title = html.escape(info["title"])
    duration = format_duration(info["duration"])
    uploader = html.escape(str(info.get("uploader", "—")))
    default_height = info.get("height") or 0
    abr = int(info.get("abr") or 128)

    lines = [
        "🔍 <b>تم التحليل</b>\n",
        f"• المنصة: {site}",
        f"• العنوان: {title}",
        f"• المدة: {duration}",
        f"• القناة/الناشر: {uploader}",
        f"• الجودة الافتراضية: {default_height if default_height else '—'}",
        f"• الصوت الافتراضي: {abr}kbps",
        "",
        "أحجام تقديرية:",
    ]

    if estimates:
        for height in sorted(estimates.keys()):
            lines.append(f"• {height}p ≈ {_kb_str(estimates[height])}")
    else:
        lines.append("• غير متوفرة")

    lines.append("")
    lines.append("اختر نوع التحميل:")

    return "\n".join(lines)


def _build_quality_keyboard(short_id: str, default_quality: str = "") -> InlineKeyboardMarkup:
    """شبكة جودات 3×2 + Best + صوت/صورة + رجوع"""
    def label(height: int) -> str:
        text = f"{height}p"
        return f"⭐ {text}" if default_quality == str(height) else text

    rows = []
    for i in range(0, len(QUALITY_GRID), 3):
        row = [
            InlineKeyboardButton(label(h), callback_data=f"dlq_{h}_{short_id}")
            for h in QUALITY_GRID[i : i + 3]
        ]
        rows.append(row)

    rows.append([InlineKeyboardButton("⚡ Best", callback_data=f"dlq_best_{short_id}")])
    rows.append(
        [
            InlineKeyboardButton("🎵 صوت MP3", callback_data=f"dl_audio_{short_id}"),
            InlineKeyboardButton("🖼 صورة مصغرة", callback_data=f"dl_thumb_{short_id}"),
        ]
    )
    rows.append([InlineKeyboardButton("🔙 رجوع", callback_data=f"dl_cancel_{short_id}")])

    return InlineKeyboardMarkup(rows)


async def on_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    await db.add_or_update_user(user.id, user.username or "", user.first_name or "")

    if await db.is_banned(user.id):
        lang = await get_lang(user.id)
        await update.message.reply_text(t("banned", lang), parse_mode="HTML")
        return

    lang = await get_lang(user.id)

    if not rate_limiter.is_allowed(user.id):
        await update.message.reply_text(t("rate_limited", lang), parse_mode="HTML")
        return

    text = update.message.text or ""
    url = extract_first_url(text)

    if not url or not is_valid_url(url):
        await update.message.reply_text(t("invalid_url", lang), parse_mode="HTML")
        return

    status_msg = await update.message.reply_text("🔍 <b>جاري التحليل...</b>", parse_mode="HTML")

    try:
        info = await get_video_info(url)
        estimates = await get_quality_estimates(url)
    except Exception as e:
        logger.error(f"فشل تحليل الرابط {url}: {e}")
        err_text = str(e).lower()
        if "login" in err_text or "authentication" in err_text or "cookies" in err_text:
            await status_msg.edit_text(
                "🔒 <b>هذا الفيديو يحتاج تسجيل دخول</b>\n\nالموقع طلب Cookies.",
                parse_mode="HTML",
            )
        else:
            await status_msg.edit_text(
                "❌ <b>تعذر تحليل هذا الرابط</b>\n\nتأكد إن الموقع مدعوم.",
                parse_mode="HTML",
            )
        return

    short_id = uuid.uuid4().hex[:8]
    _pending_urls[short_id] = url

    site = detect_site(url)
    await db.log_download(user.id, url, site, "analyzed", "pending")

    default_quality = await get_default_quality(user.id)
    caption = _build_analysis_caption(info, site, estimates)
    keyboard = _build_quality_keyboard(short_id, default_quality)
    await status_msg.edit_text(caption, parse_mode="HTML", reply_markup=keyboard)


async def on_download_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()

    user_id = query.from_user.id

    data = query.data
    parts = data.split("_", 2)
    if len(parts) < 3:
        return

    prefix, action, short_id = parts[0], parts[1], parts[2]
    url = _pending_urls.get(short_id)

    if action == "cancel":
        _pending_urls.pop(short_id, None)
        await query.edit_message_text("❌ <b>تم الإلغاء.</b>", parse_mode="HTML")
        return

    if not url:
        await query.edit_message_text(
            "⚠️ <b>انتهت صلاحية هذا الطلب</b>\n\nابعت الرابط تاني.", parse_mode="HTML"
        )
        return

    # حد التحميلات لكل مستخدم (منفصل عن حد الرسائل العام)
    if not download_rate_limiter.is_allowed(user_id):
        await query.edit_message_text(
            "⏳ <b>كثرت عليها شوية!</b>\n\nوصلت للحد المسموح من التحميلات، استنى دقيقة وحاول تاني.",
            parse_mode="HTML",
        )
        return

    try:
        await query.edit_message_text(
            "✅ <b>تم استلام طلبك.</b>\n\nسأرسل الملف فور الانتهاء.",
            parse_mode="HTML",
        )
    except Exception:
        pass

    file_path = None
    try:
        async with download_slot():
            if action == "best":
                file_path = await download_video(url, quality="custom")
                await _send_with_size_check(query, context, file_path, is_video=True)
                format_name = "Best"

            elif action.isdigit():
                height = int(action)
                file_path = await download_video(url, quality="custom", height=height)
                await _send_with_size_check(query, context, file_path, is_video=True)
                format_name = f"{height}p"

            elif action == "audio":
                file_path = await download_audio(url)
                await _send_with_size_check(query, context, file_path, is_video=False)
                format_name = "MP3"

            elif action == "thumb":
                info = await get_video_info(url)
                file_path = await download_thumbnail(info.get("thumbnail"))
                with open(file_path, "rb") as f:
                    await context.bot.send_photo(chat_id=query.message.chat_id, photo=f)
                format_name = "Thumbnail"
            else:
                format_name = action

        site = detect_site(url)
        await db.log_download(user_id, url, site, format_name, "success")
        download_logger.info(f"نجح | user={user_id} | site={site} | format={format_name} | url={url}")
        _pending_urls.pop(short_id, None)

    except Exception as e:
        logger.error(f"فشل تنفيذ التحميل للرابط {url}: {e}")
        site = detect_site(url)
        download_logger.error(f"فشل | user={user_id} | site={site} | action={action} | url={url} | error={e}")
        await context.bot.send_message(
            chat_id=query.message.chat_id,
            text="❌ <b>حصل خطأ أثناء التحميل</b>\n\nحاول تاني أو جرب رابط مختلف.",
            parse_mode="HTML",
        )
        await db.log_download(user_id, url, site, action, "failed")

    finally:
        if file_path:
            cleanup_file(file_path)


async def _send_with_size_check(query, context, file_path: str, is_video: bool):
    import os

    size_mb = os.path.getsize(file_path) / (1024 * 1024)
    if size_mb > config.MAX_FILE_SIZE_MB:
        download_logger.warning(
            f"مرفوض (حجم كبير) | user={query.from_user.id} | size={size_mb:.0f}MB "
            f"| limit={config.MAX_FILE_SIZE_MB}MB | file={file_path}"
        )
        await context.bot.send_message(
            chat_id=query.message.chat_id,
            text=(
                f"⚠️ <b>حجم الملف كبير جدًا</b>\n\n"
                f"• الحجم: {size_mb:.0f}MB\n"
                f"• الحد المسموح: {config.MAX_FILE_SIZE_MB}MB"
            ),
            parse_mode="HTML",
        )
        return

    with open(file_path, "rb") as f:
        if is_video:
            await context.bot.send_video(chat_id=query.message.chat_id, video=f, supports_streaming=True)
        else:
            await context.bot.send_audio(chat_id=query.message.chat_id, audio=f)

ZEOF_MARKER_UNIQUE
echo "✅ تم تحديث handlers/download.py"

mkdir -p $(dirname 'handlers/cookies.py')
cat > 'handlers/cookies.py' << 'ZEOF_MARKER_UNIQUE'
"""
handlers/cookies.py
أوامر الأدمن لإدارة الكوكيز:
- /check_cookies: فحص حالة كل ملفات الكوكيز (موجود/صالح/منتهي)
- /update_cookies: رفع ملف كوكيز جديد لمنصة معيّنة (عن طريق إرسال الملف كـ document بعد الأمر)
"""

from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import ContextTypes

from database.models import db
from utils.logger import logger
from utils.cookies_manager import check_all_platforms, save_cookie_file, PLATFORM_FILES

STATUS_LABELS = {
    "valid": "✅ صالح",
    "expired": "⏰ منتهي الصلاحية",
    "empty": "⚠️ فاضي/صيغة خاطئة",
    "missing": "❌ غير موجود",
}


async def is_admin_check(update: Update) -> bool:
    return await db.is_admin(update.effective_user.id)


async def cmd_check_cookies(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """فحص حالة الكوكيز لكل منصة معروفة"""
    if not await is_admin_check(update):
        await update.message.reply_text("🚫 <b>هذا الأمر للأدمن فقط.</b>", parse_mode="HTML")
        return

    results = check_all_platforms()

    lines = ["🍪 <b>حالة الكوكيز</b>\n"]
    for r in results:
        label = STATUS_LABELS.get(r["status"], r["status"])
        path_info = f" ({r['path']})" if r["path"] and r["status"] not in ("missing",) else ""
        lines.append(f"• {r['site']}: {label}{path_info}")

    lines.append(
        "\nلتحديث كوكيز منصة معيّنة استخدم:\n<code>/update_cookies اسم_المنصة</code>\n"
        "ثم ابعت ملف cookies.txt كـ Document في الرسالة اللي بعدها."
    )

    await update.message.reply_text("\n".join(lines), parse_mode="HTML")


async def cmd_update_cookies(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """بدء عملية رفع ملف كوكيز جديد لمنصة معيّنة"""
    if not await is_admin_check(update):
        await update.message.reply_text("🚫 <b>هذا الأمر للأدمن فقط.</b>", parse_mode="HTML")
        return

    if not context.args:
        keyboard = InlineKeyboardMarkup(
            [[InlineKeyboardButton(site, callback_data=f"cksite_{site}")] for site in PLATFORM_FILES]
        )
        await update.message.reply_text(
            "🍪 <b>اختر المنصة اللي عايز تحدّث كوكيزها:</b>",
            parse_mode="HTML",
            reply_markup=keyboard,
        )
        return

    site_input = " ".join(context.args)
    await _start_waiting_for_file(update, context, site_input)


async def on_cookie_site_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """معالجة اختيار المنصة من الأزرار"""
    query = update.callback_query
    await query.answer()

    if not await db.is_admin(query.from_user.id):
        await query.edit_message_text("🚫 <b>هذا الأمر للأدمن فقط.</b>", parse_mode="HTML")
        return

    site = query.data.replace("cksite_", "")
    if site not in PLATFORM_FILES:
        await query.edit_message_text("⚠️ منصة غير معروفة.")
        return

    context.user_data["awaiting_cookie_for"] = site
    await query.edit_message_text(
        f"📎 <b>تمام، دلوقتي ابعت ملف الكوكيز (cookies.txt) لـ {site} كـ Document.</b>",
        parse_mode="HTML",
    )


async def _start_waiting_for_file(update: Update, context: ContextTypes.DEFAULT_TYPE, site_input: str):
    matched = None
    for site in PLATFORM_FILES:
        if site.lower() == site_input.lower():
            matched = site
            break

    if not matched:
        sites_list = "، ".join(PLATFORM_FILES.keys())
        await update.message.reply_text(
            f"⚠️ <b>منصة غير معروفة.</b>\n\nالمنصات المتاحة: {sites_list}",
            parse_mode="HTML",
        )
        return

    context.user_data["awaiting_cookie_for"] = matched
    await update.message.reply_text(
        f"📎 <b>تمام، دلوقتي ابعت ملف الكوكيز (cookies.txt) لـ {matched} كـ Document.</b>",
        parse_mode="HTML",
    )


async def on_cookie_document(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """استقبال ملف الكوكيز المرفوع من الأدمن وحفظه في المنصة الصحيحة"""
    site = context.user_data.get("awaiting_cookie_for")
    if not site:
        return  # لا يوجد طلب تحديث كوكيز معلّق، تجاهل أي ملف عادي

    if not await db.is_admin(update.effective_user.id):
        return

    document = update.message.document
    if not document:
        return

    try:
        file = await context.bot.get_file(document.file_id)
        content = await file.download_as_bytearray()
        path = save_cookie_file(site, bytes(content))
        context.user_data.pop("awaiting_cookie_for", None)

        if path:
            await update.message.reply_text(
                f"✅ <b>تم حفظ كوكيز {site} بنجاح.</b>\n\nاستخدم /check_cookies للتأكد من الحالة.",
                parse_mode="HTML",
            )
            logger.info(f"تم تحديث كوكيز {site} من الأدمن {update.effective_user.id}")
        else:
            await update.message.reply_text("❌ فشل حفظ الملف.", parse_mode="HTML")

    except Exception as e:
        logger.error(f"فشل حفظ ملف كوكيز {site}: {e}")
        await update.message.reply_text(
            f"❌ <b>حصل خطأ أثناء حفظ الملف.</b>\n\n{e}", parse_mode="HTML"
        )
        context.user_data.pop("awaiting_cookie_for", None)

ZEOF_MARKER_UNIQUE
echo "✅ تم تحديث handlers/cookies.py"

mkdir -p $(dirname 'handlers/status.py')
cat > 'handlers/status.py' << 'ZEOF_MARKER_UNIQUE'
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

ZEOF_MARKER_UNIQUE
echo "✅ تم تحديث handlers/status.py"

echo "🗑️ حذف الملفات القديمة المكرّرة لو موجودة..."
rm -f handlers/account.py services/queue_manager.py

echo "🔍 فحص الأكواد..."
python -m py_compile bot.py config.py handlers/*.py services/*.py utils/*.py database/*.py
python3 -c "import json; json.load(open('languages/ar.json')); json.load(open('languages/en.json'))"
echo ""
echo "✅✅✅ تم بنجاح! المشروع جاهز للإنتاج. ✅✅✅"
echo ""
echo "أوامر جديدة:"
echo "  /check_cookies  - فحص حالة الكوكيز (أدمن)"
echo "  /update_cookies - تحديث كوكيز منصة معيّنة (أدمن)"
echo "  /status         - حالة البوت الشاملة (أونر فقط)"
echo ""
echo "الخطوة الجاية:"
echo "  git add ."
echo "  git commit -m 'Production readiness: cookies manager, queue, logging, rate limit, status'"
echo "  git push"
echo "  bash run.sh"