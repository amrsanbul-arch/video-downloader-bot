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

