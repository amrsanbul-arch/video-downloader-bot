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

