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

