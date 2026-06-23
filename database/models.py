"""
database/models.py
كل العمليات على قاعدة بيانات SQLite (عبر aiosqlite) بشكل غير متزامن
"""

import aiosqlite
import time
from config import config


class Database:
    def __init__(self, path: str = None):
        self.path = path or config.DATABASE_PATH
        self._conn: aiosqlite.Connection | None = None

    async def connect(self):
        self._conn = await aiosqlite.connect(self.path)
        await self._conn.execute("PRAGMA journal_mode=WAL;")
        await self.create_tables()
        await self._migrate()

    async def _migrate(self):
        """إضافة أعمدة جديدة لو لسه مش موجودة (ميجريشن بسيط وآمن)"""
        try:
            await self._conn.execute(
                "ALTER TABLE users ADD COLUMN default_quality TEXT DEFAULT '1080'"
            )
            await self._conn.commit()
        except Exception:
            pass  # العمود موجود بالفعل

    async def close(self):
        if self._conn:
            await self._conn.close()

    async def create_tables(self):
        await self._conn.executescript(
            """
            CREATE TABLE IF NOT EXISTS users (
                user_id INTEGER PRIMARY KEY,
                username TEXT,
                first_name TEXT,
                language TEXT DEFAULT 'ar',
                joined_at INTEGER,
                last_active INTEGER
            );

            CREATE TABLE IF NOT EXISTS downloads (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER,
                url TEXT,
                site TEXT,
                format TEXT,
                status TEXT,
                created_at INTEGER
            );

            CREATE TABLE IF NOT EXISTS settings (
                key TEXT PRIMARY KEY,
                value TEXT
            );

            CREATE TABLE IF NOT EXISTS banned_users (
                user_id INTEGER PRIMARY KEY,
                reason TEXT,
                banned_at INTEGER
            );

            CREATE TABLE IF NOT EXISTS admins (
                user_id INTEGER PRIMARY KEY,
                added_at INTEGER
            );
            """
        )
        await self._conn.commit()

    # ===================== المستخدمين =====================

    async def add_or_update_user(self, user_id: int, username: str, first_name: str):
        now = int(time.time())
        await self._conn.execute(
            """
            INSERT INTO users (user_id, username, first_name, joined_at, last_active)
            VALUES (?, ?, ?, ?, ?)
            ON CONFLICT(user_id) DO UPDATE SET
                username = excluded.username,
                first_name = excluded.first_name,
                last_active = excluded.last_active
            """,
            (user_id, username, first_name, now, now),
        )
        await self._conn.commit()

    async def get_user(self, user_id: int):
        cursor = await self._conn.execute(
            "SELECT * FROM users WHERE user_id = ?", (user_id,)
        )
        return await cursor.fetchone()

    async def set_user_language(self, user_id: int, lang: str):
        await self._conn.execute(
            "UPDATE users SET language = ? WHERE user_id = ?", (lang, user_id)
        )
        await self._conn.commit()

    async def get_user_language(self, user_id: int) -> str:
        row = await self.get_user(user_id)
        if row and row[3]:
            return row[3]
        return config.DEFAULT_LANGUAGE

    async def count_users(self) -> int:
        cursor = await self._conn.execute("SELECT COUNT(*) FROM users")
        row = await cursor.fetchone()
        return row[0] if row else 0

    async def get_all_user_ids(self) -> list[int]:
        cursor = await self._conn.execute("SELECT user_id FROM users")
        rows = await cursor.fetchall()
        return [r[0] for r in rows]

    # ===================== التحميلات =====================

    async def log_download(self, user_id: int, url: str, site: str, fmt: str, status: str):
        await self._conn.execute(
            """
            INSERT INTO downloads (user_id, url, site, format, status, created_at)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            (user_id, url, site, fmt, status, int(time.time())),
        )
        await self._conn.commit()

    async def count_downloads(self) -> int:
        cursor = await self._conn.execute("SELECT COUNT(*) FROM downloads")
        row = await cursor.fetchone()
        return row[0] if row else 0

    async def count_user_downloads(self, user_id: int) -> int:
        cursor = await self._conn.execute(
            "SELECT COUNT(*) FROM downloads WHERE user_id = ?", (user_id,)
        )
        row = await cursor.fetchone()
        return row[0] if row else 0

    async def get_recent_downloads(self, user_id: int, limit: int = 5):
        """جلب آخر التحميلات الناجحة للمستخدم"""
        cursor = await self._conn.execute(
            """
            SELECT url, site, format, created_at FROM downloads
            WHERE user_id = ? AND status = 'success'
            ORDER BY created_at DESC LIMIT ?
            """,
            (user_id, limit),
        )
        return await cursor.fetchall()

    async def get_recent_downloads(self, user_id: int, limit: int = 5):
        """آخر تحميلات المستخدم (الأحدث أولًا)"""
        cursor = await self._conn.execute(
            """
            SELECT url, site, format, status, created_at
            FROM downloads
            WHERE user_id = ?
            ORDER BY id DESC
            LIMIT ?
            """,
            (user_id, limit),
        )
        return await cursor.fetchall()

    async def set_default_quality(self, user_id: int, quality: str):
        await self._conn.execute(
            "UPDATE users SET default_quality = ? WHERE user_id = ?",
            (quality, user_id),
        )
        await self._conn.commit()

    async def get_default_quality(self, user_id: int) -> str:
        cursor = await self._conn.execute(
            "SELECT default_quality FROM users WHERE user_id = ?", (user_id,)
        )
        row = await cursor.fetchone()
        return row[0] if row and row[0] else "1080"

    # ===================== الحظر =====================

    async def ban_user(self, user_id: int, reason: str = ""):
        await self._conn.execute(
            "INSERT OR REPLACE INTO banned_users (user_id, reason, banned_at) VALUES (?, ?, ?)",
            (user_id, reason, int(time.time())),
        )
        await self._conn.commit()

    async def unban_user(self, user_id: int):
        await self._conn.execute(
            "DELETE FROM banned_users WHERE user_id = ?", (user_id,)
        )
        await self._conn.commit()

    async def is_banned(self, user_id: int) -> bool:
        cursor = await self._conn.execute(
            "SELECT 1 FROM banned_users WHERE user_id = ?", (user_id,)
        )
        return await cursor.fetchone() is not None

    # ===================== الأدمنز =====================

    async def add_admin(self, user_id: int):
        await self._conn.execute(
            "INSERT OR IGNORE INTO admins (user_id, added_at) VALUES (?, ?)",
            (user_id, int(time.time())),
        )
        await self._conn.commit()

    async def remove_admin(self, user_id: int):
        await self._conn.execute("DELETE FROM admins WHERE user_id = ?", (user_id,))
        await self._conn.commit()

    async def get_admin_ids(self) -> list[int]:
        cursor = await self._conn.execute("SELECT user_id FROM admins")
        rows = await cursor.fetchall()
        return [r[0] for r in rows] + config.ADMIN_IDS + [config.OWNER_ID]

    async def is_admin(self, user_id: int) -> bool:
        if user_id == config.OWNER_ID or user_id in config.ADMIN_IDS:
            return True
        cursor = await self._conn.execute(
            "SELECT 1 FROM admins WHERE user_id = ?", (user_id,)
        )
        return await cursor.fetchone() is not None

    # ===================== الإعدادات =====================

    async def get_setting(self, key: str, default=None):
        cursor = await self._conn.execute(
            "SELECT value FROM settings WHERE key = ?", (key,)
        )
        row = await cursor.fetchone()
        return row[0] if row else default

    async def set_setting(self, key: str, value: str):
        await self._conn.execute(
            "INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)",
            (key, value),
        )
        await self._conn.commit()


# نسخة واحدة مشتركة تُستخدم في كل المشروع
db = Database()

