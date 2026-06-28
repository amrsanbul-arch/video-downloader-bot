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

