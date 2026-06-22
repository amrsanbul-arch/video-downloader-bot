"""
utils/i18n.py
تحميل ملفات اللغات (ar.json / en.json) وإرجاع النص المطلوب بسهولة
"""

import json
import os

_LANG_DIR = "languages"
_cache: dict[str, dict] = {}


def _load_language(lang: str) -> dict:
    if lang in _cache:
        return _cache[lang]

    path = os.path.join(_LANG_DIR, f"{lang}.json")
    if not os.path.exists(path):
        path = os.path.join(_LANG_DIR, "ar.json")  # رجوع للعربي كافتراضي

    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)

    _cache[lang] = data
    return data


def t(key: str, lang: str = "ar", **kwargs) -> str:
    """جلب نص مترجم باستخدام مفتاحه، مع دعم وضع متغيرات داخل النص"""
    data = _load_language(lang)
    text = data.get(key)

    if text is None:
        # fallback للعربي لو المفتاح غير موجود في اللغة المطلوبة
        text = _load_language("ar").get(key, key)

    try:
        return text.format(**kwargs)
    except (KeyError, IndexError):
        return text
