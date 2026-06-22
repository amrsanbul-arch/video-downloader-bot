"""
utils/validators.py
دوال مساعدة للتحقق من صحة الروابط ونوع الموقع
"""

import re

URL_REGEX = re.compile(
    r"^(https?://)?(www\.)?[\w\-]+\.[a-z]{2,}(/[\w\-./?%&=]*)?$",
    re.IGNORECASE,
)

SITE_PATTERNS = {
    "YouTube": r"(youtube\.com|youtu\.be)",
    "TikTok": r"tiktok\.com",
    "Facebook": r"(facebook\.com|fb\.watch)",
    "Instagram": r"instagram\.com",
    "X (Twitter)": r"(twitter\.com|x\.com)",
    "Snapchat": r"snapchat\.com",
    "Reddit": r"reddit\.com",
    "Pinterest": r"pinterest\.",
    "Vimeo": r"vimeo\.com",
    "Dailymotion": r"dailymotion\.com",
}


def is_valid_url(text: str) -> bool:
    """التحقق إذا كان النص رابط صحيح"""
    if not text:
        return False
    return bool(URL_REGEX.match(text.strip()))


def detect_site(url: str) -> str:
    """تحديد اسم الموقع من الرابط، أو 'Other' لو غير معروف لكن مدعوم عبر yt-dlp"""
    for site, pattern in SITE_PATTERNS.items():
        if re.search(pattern, url, re.IGNORECASE):
            return site
    return "Other"


def extract_first_url(text: str) -> str | None:
    """استخراج أول رابط من نص الرسالة"""
    match = re.search(r"https?://\S+", text)
    return match.group(0) if match else None
