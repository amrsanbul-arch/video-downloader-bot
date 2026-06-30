#!/data/data/com.termux/files/usr/bin/bash
# mission_production_hardening.sh
set -e
echo "🔧 تطبيق Mission: Professional Refactor & Production Hardening..."

mkdir -p cookies logs downloads backups
touch cookies/.gitkeep logs/.gitkeep backups/.gitkeep

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

# استخراج الكوكيز من متصفح سطح المكتب (اختياري، يعمل فقط على Linux/VPS/Docker)
# يُتجاهل تلقائيًا على Termux/Android - اتركه فاضي إذا كنت تستخدم الموبايل
# القيم المقبولة: chrome, firefox, edge, brave, opera, vivaldi, safari
BROWSER_COOKIES_BROWSER=

# ===== Proxy (اختياري) - يدعم HTTP/HTTPS/SOCKS5 =====
# مثال: http://user:pass@host:port أو socks5://host:port
# اتركه فاضي للعمل بدون بروكسي (الوضع الطبيعي)
PROXY_URL=

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
# حد أقصى إضافي على مستوى السيمافور العام (حماية موارد إضافية)
DOWNLOAD_SEMAPHORE_LIMIT=3

# ===== تنظيف الملفات المؤقتة تلقائيًا =====
# حذف أي ملف في downloads/ عمره أكبر من القيمة دي (بالدقايق)
CLEANUP_MAX_AGE_MINUTES=60
# كل كام دقيقة تشتغل وظيفة التنظيف التلقائي
CLEANUP_INTERVAL_MINUTES=15

# ===== كاش بيانات الفيديو المؤقت (لتقليل طلبات yt-dlp المتكررة) =====
VIDEO_CACHE_TTL_SECONDS=300

# ===== النسخ الاحتياطي لقاعدة البيانات =====
BACKUP_DIR=backups
BACKUP_INTERVAL_HOURS=24
BACKUP_KEEP_LAST=7

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
database/*.db
database/*.db-shm
database/*.db-wal
*.db
*.sqlite3
downloads/*
!downloads/.gitkeep
logs/*
!logs/.gitkeep
backups/*
!backups/.gitkeep
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
from utils.logger import logger, log_startup

from handlers import start, help as help_handler, settings, admin, download
from handlers import admin_dashboard, force_subscribe, menu, cookies, status, maintenance
from services.cleanup_service import cleanup_job
from services.backup_service import backup_job
from services.video_cache import cleanup_cache_job


async def on_error(update: object, context: ContextTypes.DEFAULT_TYPE):
    logger.error(f"حدث خطأ غير متوقع: {context.error}", exc_info=context.error)


async def post_init(application: Application):
    await db.connect()
    logger.info("✅ تم الاتصال بقاعدة البيانات بنجاح")
    log_startup(f"البوت بدأ التشغيل بنجاح | الإصدار: 3.0 | PID: {__import__('os').getpid()}")


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
        .read_timeout(60)
        .write_timeout(180)
        .pool_timeout(60)
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

    # ===== أوامر الصيانة الجديدة (أدمن) =====
    app.add_handler(CommandHandler("health", maintenance.cmd_health))
    app.add_handler(CommandHandler("cleanup", maintenance.cmd_cleanup))
    app.add_handler(CommandHandler("backup", maintenance.cmd_backup))
    # ملحوظة: أمر /stats الموجود (settings.cmd_stats) هو إحصائيات المستخدم الشخصية.
    # لا نغيّره حفاظًا على التوافق العكسي - الإحصائيات الإدارية الشاملة متاحة عبر /botstats الموجود مسبقًا.

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

    # ===== الوظائف الدورية (Job Queue) =====
    # ملحوظة: job_queue يتطلب تثبيت: pip install "python-telegram-bot[job-queue]"
    # في حالة عدم توفره، نتجاهل الجدولة الدورية بدون كسر تشغيل البوت (الأوامر اليدوية /cleanup و /backup تبقى تعمل)
    if app.job_queue is not None:
        app.job_queue.run_repeating(
            cleanup_job,
            interval=config.CLEANUP_INTERVAL_MINUTES * 60,
            first=60,
            name="auto_cleanup_downloads",
        )
        app.job_queue.run_repeating(
            backup_job,
            interval=config.BACKUP_INTERVAL_HOURS * 3600,
            first=300,
            name="auto_database_backup",
        )
        app.job_queue.run_repeating(
            cleanup_cache_job,
            interval=config.VIDEO_CACHE_TTL_SECONDS,
            first=config.VIDEO_CACHE_TTL_SECONDS,
            name="auto_cleanup_video_cache",
        )
        logger.info("✅ تم تفعيل الوظائف الدورية (تنظيف، نسخ احتياطي، كاش)")
    else:
        logger.warning(
            "⚠️ job_queue غير متاح - الوظائف الدورية معطّلة. "
            "ثبّت: pip install \"python-telegram-bot[job-queue]\" لتفعيلها. "
            "الأوامر اليدوية /cleanup و /backup تعمل بشكل طبيعي."
        )

    logger.info("✅ البوت شغال دلوقتي...")
    app.run_polling(allowed_updates=Update.ALL_TYPES)


if __name__ == "__main__":
    main()

ZEOF_MARKER_UNIQUE
echo "✅ تم تحديث bot.py"

mkdir -p $(dirname 'run.sh')
cat > 'run.sh' << 'ZEOF_MARKER_UNIQUE'
#!/data/data/com.termux/files/usr/bin/bash
# run.sh
# يشغّل البوت مع: فحص المتطلبات، تفعيل virtualenv (لو موجود)، إعادة تشغيل تلقائي عند الكراش
# مصمم للعمل بدون أي مشاكل على Termux/Android بدون الاعتماد على systemd

cd "$(dirname "$0")"

# ===== تفعيل virtualenv لو موجود (لأنظمة Linux/VPS فقط - على Termux غالبًا غير مستخدم) =====
if [ -f "venv/bin/activate" ]; then
    echo "🐍 تفعيل virtualenv..."
    source venv/bin/activate
fi

# ===== فحص بسيط للمتطلبات الأساسية قبل التشغيل =====
if ! command -v python >/dev/null 2>&1; then
    echo "❌ Python غير مثبّت أو غير موجود في PATH."
    exit 1
fi

if [ ! -f "bot.py" ]; then
    echo "❌ ملف bot.py غير موجود في هذا المجلد."
    exit 1
fi

if [ ! -f ".env" ]; then
    echo "⚠️ تحذير: ملف .env غير موجود. تأكد من إنشائه من .env.example قبل التشغيل."
fi

# ===== منع Android من إيقاف Termux في الخلفية =====
# يحتاج أيضًا: إعدادات الموبايل > التطبيقات > Termux > البطارية > بدون قيود (Unrestricted)
if command -v termux-wake-lock >/dev/null 2>&1; then
    termux-wake-lock
    echo "🔒 تم تفعيل termux-wake-lock (منع Android من إيقاف التطبيق في الخلفية)"
else
    echo "💡 لمنع Android من إيقاف البوت في الخلفية، ثبّت: pkg install termux-api"
fi

echo "🚀 بدء حلقة التشغيل الدائم للبوت..."
echo "(لإيقاف البوت نهائيًا: اضغط Ctrl+C مرتين بسرعة)"
echo ""

# ===== حلقة إعادة التشغيل التلقائي (بديل بسيط عن systemd، يعمل على أي بيئة Linux/Termux) =====
RESTART_COUNT=0
while true; do
    python bot.py
    EXIT_CODE=$?
    RESTART_COUNT=$((RESTART_COUNT + 1))
    echo ""
    echo "⚠️ البوت توقف (exit code: $EXIT_CODE). إعادة التشغيل رقم $RESTART_COUNT بعد 5 ثواني..."
    sleep 5
done

ZEOF_MARKER_UNIQUE
chmod +x 'run.sh'
echo "✅ تم تحديث run.sh"

mkdir -p $(dirname 'requirements.txt')
cat > 'requirements.txt' << 'ZEOF_MARKER_UNIQUE'
python-telegram-bot[job-queue]==21.6
yt-dlp>=2024.10.7
python-dotenv>=1.0.1
aiosqlite>=0.20.0
aiohttp>=3.9.5
psutil>=5.9.0

ZEOF_MARKER_UNIQUE
echo "✅ تم تحديث requirements.txt"

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

ZEOF_MARKER_UNIQUE
echo "✅ تم تحديث utils/logger.py"

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
import platform
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


def _is_termux() -> bool:
    """التحقق إذا كان البوت شغال داخل Termux (Android) - لتعطيل ميزات سطح المكتب فقط"""
    return "ANDROID_ROOT" in os.environ or "com.termux" in os.environ.get("PREFIX", "")


def get_browser_cookies_option() -> tuple | None:
    """
    يرجع خيار yt-dlp لاستخراج الكوكيز من متصفح سطح المكتب (مثل Chrome)،
    أو None لو شغالين على Termux/Android (غير مدعوم أصلاً على الموبايل) أو لو معطّل في .env

    يُستخدم كأولوية ثالثة (آخر حل) بعد ملف المنصة المخصص وملف COOKIES_FILE العام
    """
    if not config.BROWSER_COOKIES_BROWSER:
        return None

    if _is_termux():
        # --cookies-from-browser غير مدعوم على Termux (لا يوجد متصفح حقيقي بنفس صيغة سطح المكتب)
        return None

    # yt-dlp يقبل هذا كـ tuple: (browser_name,)
    return (config.BROWSER_COOKIES_BROWSER,)


def get_cookie_path(site: str) -> str | None:
    """
    إرجاع مسار ملف الكوكيز الخاص بالمنصة لو موجود فعليًا،
    أو COOKIES_FILE القديم كـ fallback، أو None لو لا يوجد أي منهما

    ملحوظة: لا يشمل browser cookies (تلك حالة خاصة تُدار في get_ydl_cookie_opts)
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


def get_ydl_cookie_opts(site: str) -> dict:
    """
    بناء قاموس خيارات yt-dlp الخاص بالكوكيز فقط، بترتيب أولوية واضح:
    1) ملف كوكيز المنصة المخصص (cookies/youtube.txt مثلاً)
    2) ملف COOKIES_FILE العام كـ fallback
    3) browser cookies (سطح المكتب فقط، يتم تجاهله تلقائيًا على Termux)
    4) بدون كوكيز خالص (تحميل عام بدون تسجيل دخول)

    لا يرفع أي استثناء أبدًا - أسوأ حالة هي إرجاع dict فاضي (تحميل بدون كوكيز)
    """
    try:
        cookie_path = get_cookie_path(site)
        if cookie_path:
            return {"cookiefile": cookie_path}

        browser_option = get_browser_cookies_option()
        if browser_option:
            logger.info(f"لا يوجد ملف كوكيز لـ {site}، استخدام كوكيز المتصفح كـ fallback")
            return {"cookiesfrombrowser": browser_option}

    except Exception as e:
        logger.warning(f"خطأ غير متوقع أثناء تحديد كوكيز {site}، سيتم التحميل بدون كوكيز: {e}")

    return {}


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

# مسارات الملفات الجاري تحميلها/رفعها حاليًا (لمنع cleanup_service من حذفها بالخطأ)
_active_file_paths: set[str] = set()

# قفل مستقل لكل مستخدم (Anti-Flood): يضمن إن طلبات نفس المستخدم تُعالج بالتسلسل
# لو بعت 5 روابط بسرعة، هتتنفذ واحد ورا الآخر بدل ما تتزاحم على الموارد كلها مرة واحدة
_user_locks: dict[int, asyncio.Lock] = {}


def _get_user_lock(user_id: int) -> asyncio.Lock:
    """إرجاع قفل المستخدم، مع إنشائه تلقائيًا أول مرة"""
    if user_id not in _user_locks:
        _user_locks[user_id] = asyncio.Lock()
    return _user_locks[user_id]


@asynccontextmanager
async def user_download_slot(user_id: int, file_path: str | None = None):
    """
    Context manager شامل (Anti-Flood + طابور عام):
    1) ينتظر دوره في قفل المستخدم نفسه (يمنع تزاحم نفس المستخدم لو بعت روابط متعددة بسرعة)
    2) بعد كده ينتظر في الطابور العام (Semaphore) لو كل السلوتات مشغولة بمستخدمين آخرين
    """
    user_lock = _get_user_lock(user_id)
    async with user_lock:
        async with download_slot(file_path):
            yield


@asynccontextmanager
async def download_slot(file_path: str | None = None):
    """
    Context manager: ينتظر في الطابور لو التحميلات الحالية وصلت للحد الأقصى،
    ثم يحجز "سلوت" تحميل، ويحرره تلقائيًا في النهاية حتى لو حصل استثناء (finally)

    file_path: لو محدد، يُضاف لقائمة الملفات النشطة طول مدة التحميل
    (نظام التنظيف التلقائي لا يحذف أي ملف موجود في هذه القائمة)
    """
    global _active_count, _waiting_count

    _waiting_count += 1
    acquired = False
    try:
        await _semaphore.acquire()
        acquired = True
        _waiting_count -= 1
        _active_count += 1
        if file_path:
            _active_file_paths.add(file_path)
        yield
    finally:
        if file_path:
            _active_file_paths.discard(file_path)
        if acquired:
            _active_count -= 1
            _semaphore.release()
        else:
            _waiting_count -= 1


def get_active_file_paths() -> set[str]:
    """إرجاع نسخة من مسارات الملفات النشطة حاليًا (للاستخدام في cleanup_service)"""
    return set(_active_file_paths)


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
from utils.cookies_manager import get_ydl_cookie_opts

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
    if site:
        opts.update(get_ydl_cookie_opts(site))
    if config.PROXY_URL:
        opts["proxy"] = config.PROXY_URL
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
from utils.cookies_manager import get_ydl_cookie_opts

DOWNLOAD_DIR = config.DOWNLOAD_DIR


def _apply_common_opts(opts: dict, site: str = None) -> dict:
    """
    إضافة الخيارات المشتركة (كوكيز + بروكسي) لأي قاموس خيارات yt-dlp
    - الكوكيز: عبر منطق fallback ثلاثي الأولوية في cookies_manager
    - البروكسي: يُضاف فقط لو PROXY_URL محدد في .env (يدعم HTTP/HTTPS/SOCKS5)
    """
    if site:
        opts.update(get_ydl_cookie_opts(site))
    if config.PROXY_URL:
        opts["proxy"] = config.PROXY_URL
    return opts


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
    return _apply_common_opts(opts, site)


def _extract_info_sync(url: str, site: str = None) -> dict:
    """استخراج معلومات الفيديو بدون تحميل (تشغيل sync داخل thread)"""
    opts = {
        "quiet": True,
        "no_warnings": True,
        "noplaylist": True,
        "skip_download": True,
    }
    opts = _apply_common_opts(opts, site)
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

mkdir -p $(dirname 'services/cleanup_service.py')
cat > 'services/cleanup_service.py' << 'ZEOF_MARKER_UNIQUE'
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

ZEOF_MARKER_UNIQUE
echo "✅ تم تحديث services/cleanup_service.py"

mkdir -p $(dirname 'services/backup_service.py')
cat > 'services/backup_service.py' << 'ZEOF_MARKER_UNIQUE'
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

ZEOF_MARKER_UNIQUE
echo "✅ تم تحديث services/backup_service.py"

mkdir -p $(dirname 'services/video_cache.py')
cat > 'services/video_cache.py' << 'ZEOF_MARKER_UNIQUE'
"""
services/video_cache.py
كاش مؤقت في الذاكرة لبيانات الفيديو (معلومات + جودات متاحة):
- لو أكتر من مستخدم بعت نفس الرابط في فترة قصيرة، نتجنب تكرار طلب yt-dlp بالكامل
- صلاحية كل عنصر محدودة بـ VIDEO_CACHE_TTL_SECONDS (افتراضيًا 5 دقايق)
- تنظيف تلقائي للعناصر منتهية الصلاحية عبر job_queue
"""

import time
from config import config
from utils.logger import logger

# الشكل: { url: {"info": dict, "estimates": dict, "expires_at": float} }
_video_cache: dict[str, dict] = {}


def get_cached(url: str) -> dict | None:
    """
    إرجاع بيانات الفيديو المخزّنة لو موجودة وغير منتهية الصلاحية، وإلا None
    """
    entry = _video_cache.get(url)
    if not entry:
        return None

    if time.time() > entry["expires_at"]:
        _video_cache.pop(url, None)
        return None

    return entry


def set_cached(url: str, info: dict, estimates: dict):
    """تخزين بيانات فيديو جديدة في الكاش مع وقت انتهاء صلاحية"""
    _video_cache[url] = {
        "info": info,
        "estimates": estimates,
        "expires_at": time.time() + config.VIDEO_CACHE_TTL_SECONDS,
    }


def invalidate(url: str):
    """حذف عنصر معيّن من الكاش يدويًا (مثلاً لو فشل التحميل وعايزين نجرب من جديد)"""
    _video_cache.pop(url, None)


def cleanup_cache() -> int:
    """حذف كل العناصر منتهية الصلاحية من الكاش، يرجع عدد العناصر المحذوفة"""
    now = time.time()
    expired_keys = [url for url, entry in _video_cache.items() if now > entry["expires_at"]]
    for url in expired_keys:
        _video_cache.pop(url, None)
    return len(expired_keys)


def get_cache_size() -> int:
    """عدد العناصر المخزّنة حاليًا في الكاش (يُستخدم في /status)"""
    return len(_video_cache)


async def cleanup_cache_job(context) -> None:
    """دالة Job Queue لتنظيف الكاش دوريًا - لا تتسبب في توقف البوت أبدًا حتى لو فشلت"""
    try:
        removed = cleanup_cache()
        if removed > 0:
            logger.info(f"تنظيف الكاش: تم حذف {removed} عنصر منتهي الصلاحية")
    except Exception as e:
        logger.error(f"فشلت وظيفة تنظيف الكاش الدورية: {e}")

ZEOF_MARKER_UNIQUE
echo "✅ تم تحديث services/video_cache.py"

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
from utils.download_tracker import user_download_slot, get_active_file_paths
from services.video_cache import get_cached, set_cached
from handlers.menu import get_default_quality

download_logger = get_download_logger()

_pending_urls: dict[str, str] = {}
# مسارات الملفات الجاري رفعها حاليًا (حماية إضافية من حذفها بواسطة cleanup التلقائي)
_locally_active_files: set[str] = set()

QUALITY_GRID = [144, 240, 360, 480, 720, 1080]


def _mark_file_active(path: str):
    _locally_active_files.add(path)


def _unmark_file_active(path: str):
    _locally_active_files.discard(path)


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

    # محاولة القراءة من الكاش أولاً (يقلل طلبات yt-dlp المتكررة لنفس الرابط)
    cached = get_cached(url)
    if cached:
        info = cached["info"]
        estimates = cached["estimates"]
    else:
        try:
            info = await get_video_info(url)
            estimates = await get_quality_estimates(url)
            set_cached(url, info, estimates)
        except Exception as e:
            logger.error(f"فشل تحليل الرابط {url}: {e}")
            err_text = str(e).lower()
            if "login" in err_text or "authentication" in err_text or "cookies" in err_text:
                await status_msg.edit_text(
                    "🔒 <b>هذا الفيديو يحتاج تسجيل دخول</b>\n\n"
                    "الموقع طلب Cookies، وممكن تكون الكوكيز المحفوظة قديمة أو منتهية.\n"
                    "جرب تحدّثها عبر /update_cookies (إذا كنت أدمن) أو حاول رابط مختلف.",
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
        async with user_download_slot(user_id):
            if action == "best":
                file_path = await download_video(url, quality="custom")
                _mark_file_active(file_path)
                await _send_with_size_check(query, context, file_path, is_video=True)
                format_name = "Best"

            elif action.isdigit():
                height = int(action)
                file_path = await download_video(url, quality="custom", height=height)
                _mark_file_active(file_path)
                await _send_with_size_check(query, context, file_path, is_video=True)
                format_name = f"{height}p"

            elif action == "audio":
                file_path = await download_audio(url)
                _mark_file_active(file_path)
                await _send_with_size_check(query, context, file_path, is_video=False)
                format_name = "MP3"

            elif action == "thumb":
                info = await get_video_info(url)
                file_path = await download_thumbnail(info.get("thumbnail"))
                _mark_file_active(file_path)
                with open(file_path, "rb") as f:
                    await context.bot.send_photo(
                        chat_id=query.message.chat_id,
                        photo=f,
                        read_timeout=120,
                        write_timeout=120,
                        connect_timeout=60,
                    )
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
            _unmark_file_active(file_path)
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
            await context.bot.send_video(
                chat_id=query.message.chat_id,
                video=f,
                supports_streaming=True,
                read_timeout=300,
                write_timeout=300,
                connect_timeout=60,
            )
        else:
            await context.bot.send_audio(
                chat_id=query.message.chat_id,
                audio=f,
                read_timeout=300,
                write_timeout=300,
                connect_timeout=60,
            )

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
from services.video_cache import get_cache_size

_start_time = time.time()


def get_start_time() -> float:
    """وقت بدء تشغيل البوت (Unix timestamp) - يُستخدم في /status و /health"""
    return _start_time


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

    try:
        cache_size = get_cache_size()
    except Exception:
        cache_size = "—"

    text = (
        "📡 <b>حالة البوت</b>\n\n"
        f"• الحالة: ✅ شغال\n"
        f"• مدة التشغيل: {uptime}\n\n"
        f"🗄️ <b>قاعدة البيانات:</b> {db_status}\n"
        f"• المستخدمين: {users_count}\n"
        f"• التحميلات: {downloads_count}\n\n"
        f"🍪 <b>الكوكيز:</b> {cookies_summary}\n\n"
        f"💾 <b>التخزين:</b>\n{disk_line}\n\n"
        f"📥 <b>طابور التحميل:</b>\n{queue_line}\n\n"
        f"🧠 <b>الكاش:</b> {cache_size} فيديو مخزّن مؤقتًا"
    )

    await update.message.reply_text(text, parse_mode="HTML")

ZEOF_MARKER_UNIQUE
echo "✅ تم تحديث handlers/status.py"

mkdir -p $(dirname 'handlers/maintenance.py')
cat > 'handlers/maintenance.py' << 'ZEOF_MARKER_UNIQUE'
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

ZEOF_MARKER_UNIQUE
echo "✅ تم تحديث handlers/maintenance.py"

echo "🔍 فحص الأكواد..."
python -m py_compile bot.py config.py handlers/*.py services/*.py utils/*.py database/*.py
python3 -c "import json; json.load(open('languages/ar.json')); json.load(open('languages/en.json'))"
echo ""
echo "📦 تثبيت المكتبات الإضافية (job-queue, psutil)..."
pip install -r requirements.txt --upgrade 2>/dev/null || pip install -r requirements.txt --upgrade --break-system-packages 2>&1 | tail -5 || true
echo ""
echo "✅✅✅ تم بنجاح! المشروع جاهز للإنتاج (Production Hardened). ✅✅✅"
echo ""
echo "أوامر جديدة:"
echo "  /health   - صحة النظام: CPU, RAM, Disk (أدمن)"
echo "  /cleanup  - تنظيف يدوي فوري لمجلد التحميلات (أدمن)"
echo "  /backup   - نسخة احتياطية فورية لقاعدة البيانات (أدمن)"
echo ""
echo "ميزات تلقائية جديدة:"
echo "  - تنظيف الملفات القديمة كل 15 دقيقة تلقائيًا"
echo "  - نسخة احتياطية يومية تلقائية (آخر 7 نسخ محفوظة)"
echo "  - كاش بيانات الفيديو 5 دقائق (تقليل تكرار الطلبات)"
echo "  - حماية Anti-Flood: طلبات كل مستخدم تُعالج بالتسلسل"
echo ""
echo "الخطوة الجاية:"
echo "  git add ."
echo "  git commit -m 'Production hardening: cleanup jobs, backups, cache, proxy, anti-flood, health'"
echo "  git push"
echo "  bash run.sh"