"""
services/thumbnail.py
تحميل الصورة المصغرة (Thumbnail) للفيديو
"""

import os
import uuid
import asyncio
import aiohttp

from config import config

DOWNLOAD_DIR = config.DOWNLOAD_DIR


async def download_thumbnail(thumbnail_url: str) -> str:
    """
    تحميل صورة Thumbnail من رابطها المباشر وحفظها محليًا
    يرجع مسار الصورة المحفوظة
    """
    if not thumbnail_url:
        raise ValueError("لا يوجد رابط صورة مصغرة لهذا الفيديو")

    file_id = uuid.uuid4().hex[:10]
    ext = ".jpg"
    if "." in thumbnail_url.split("/")[-1]:
        possible_ext = "." + thumbnail_url.split("/")[-1].split(".")[-1].split("?")[0]
        if len(possible_ext) <= 5:
            ext = possible_ext

    out_path = os.path.join(DOWNLOAD_DIR, f"{file_id}{ext}")

    timeout = aiohttp.ClientTimeout(total=config.DOWNLOAD_TIMEOUT)
    async with aiohttp.ClientSession(timeout=timeout) as session:
        async with session.get(thumbnail_url) as resp:
            resp.raise_for_status()
            content = await resp.read()

    with open(out_path, "wb") as f:
        f.write(content)

    return out_path
