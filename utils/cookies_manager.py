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

