# 🎬 بوت تحميل الفيديوهات (Video Downloader Bot)

بوت Telegram احترافي لتحميل الفيديوهات والصوتيات من مواقع التواصل الاجتماعي، مبني بـ Python و yt-dlp.

## ✨ المميزات

- تحميل فيديو/صوت/صورة مصغرة من: YouTube, TikTok, Facebook, Instagram, X (Twitter), Snapchat, Reddit, Pinterest, Vimeo, Dailymotion، وأي موقع يدعمه yt-dlp.
- أزرار جودة تفاعلية (عالي / متوسط / MP3 / صورة مصغرة).
- نظام مستخدمين وإدارة كامل (حظر، برودكاست، إحصائيات).
- دعم لغتين: عربي وإنجليزي.
- Rate Limit لمنع السبام.
- قاعدة بيانات SQLite (غير متزامنة عبر aiosqlite).
- نظام تسجيل أخطاء (Logging) باحترافية.
- دعم Docker للتشغيل على VPS بسهولة.
- دعم Termux للتشغيل من الموبايل مباشرة.

## 📁 هيكل المشروع

```
video_bot/
├── bot.py                  # نقطة التشغيل الرئيسية
├── config.py                # قراءة الإعدادات من .env
├── requirements.txt
├── .env.example
├── Dockerfile
├── docker-compose.yml
├── LICENSE
├── handlers/
│   ├── start.py              # /start /about /ping /lang
│   ├── help.py                # /help
│   ├── settings.py            # /settings /stats
│   ├── admin.py                # أوامر الإدارة
│   └── download.py            # استقبال الروابط وأزرار التحميل
├── services/
│   ├── downloader.py           # تحميل الفيديو عبر yt-dlp
│   ├── audio.py                 # استخراج MP3
│   └── thumbnail.py              # تحميل الصورة المصغرة
├── database/
│   └── models.py                  # جداول وعمليات SQLite
├── utils/
│   ├── logger.py
│   ├── validators.py
│   ├── helpers.py                  # Rate Limit + تنسيق الحجم/المدة
│   └── i18n.py                      # نظام الترجمة
├── languages/
│   ├── ar.json
│   └── en.json
├── logs/
└── downloads/
```

## 🚀 التشغيل على Termux (أندرويد)

```bash
pkg update && pkg upgrade -y
pkg install python git ffmpeg -y

git clone https://github.com/amrsanbul-arch/video-downloader-bot.git
cd video-downloader-bot

pip install -r requirements.txt

cp .env.example .env
nano .env   # ضع BOT_TOKEN و OWNER_ID

python bot.py
```

## 🚀 التشغيل على Linux / VPS

```bash
sudo apt update && sudo apt install python3 python3-pip ffmpeg git -y

git clone https://github.com/amrsanbul-arch/video-downloader-bot.git
cd video-downloader-bot

python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

cp .env.example .env
nano .env

python3 bot.py
```

### التشغيل بشكل دائم (systemd) - اختياري

```bash
sudo nano /etc/systemd/system/videobot.service
```

```ini
[Unit]
Description=Video Downloader Telegram Bot
After=network.target

[Service]
WorkingDirectory=/path/to/video-downloader-bot
ExecStart=/path/to/video-downloader-bot/venv/bin/python bot.py
Restart=always
User=your_user

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl enable videobot
sudo systemctl start videobot
```

## 🐳 التشغيل بـ Docker

```bash
cp .env.example .env
nano .env

docker compose up -d --build
```

## ⚙️ الإعدادات (.env)

| المتغير | الوصف |
|---|---|
| `BOT_TOKEN` | توكن البوت من [@BotFather](https://t.me/BotFather) |
| `OWNER_ID` | آيدي تليجرام بتاعك (المالك الكامل للبوت) |
| `ADMIN_IDS` | آيديز مشرفين إضافيين، مفصولة بفاصلة |
| `MAX_FILE_SIZE_MB` | الحد الأقصى لحجم الملف المسموح برفعه |
| `DOWNLOAD_DIR` | مجلد التحميلات المؤقتة |
| `DATABASE_PATH` | مسار قاعدة البيانات |
| `DEFAULT_LANGUAGE` | اللغة الافتراضية (ar / en) |
| `RATE_LIMIT_MESSAGES` / `RATE_LIMIT_SECONDS` | حد عدد الرسائل المسموح بها في فترة زمنية |

## 📜 الأوامر

### أوامر المستخدم
| الأمر | الوظيفة |
|---|---|
| `/start` | بدء استخدام البوت |
| `/help` | عرض المساعدة |
| `/about` | معلومات عن البوت |
| `/settings` | الإعدادات الحالية |
| `/stats` | إحصائياتك الشخصية |
| `/lang` | تغيير اللغة |
| `/ping` | فحص سرعة استجابة البوت |

### أوامر الإدارة (تتطلب صلاحية أدمن/أونر)
| الأمر | الوظيفة |
|---|---|
| `/broadcast <رسالة>` | إرسال رسالة لكل المستخدمين |
| `/users` | عدد المستخدمين الكلي |
| `/botstats` | إحصائيات شاملة للبوت |
| `/ban <id> [سبب]` | حظر مستخدم |
| `/unban <id>` | رفع الحظر |
| `/logs` | تنزيل ملف السجل (logs) |
| `/restart` | إعادة تشغيل العملية (يتطلب مدير عمليات مثل systemd/pm2) |
| `/update` | سحب آخر تحديثات المشروع عبر `git pull` |

> ⚠️ ملاحظة: تم استخدام `/botstats` للإحصائيات الإدارية الشاملة بدل `/stats` لتجنب التعارض مع أمر `/stats` الخاص بالمستخدم العادي.

## 🔄 التحديث التلقائي

استخدم أمر `/update` من داخل البوت (للأدمن فقط) — ينفذ `git pull` على المجلد، يفترض إن المشروع مستنسخ كـ Git repo. بعدها استخدم `/restart` (مع systemd أو pm2 أو screen) لإعادة تحميل الكود الجديد.

## 🛠 استكشاف الأخطاء

- لو ظهر خطأ `ffmpeg not found`: تأكد إنك مثبت `ffmpeg` (مطلوب لدمج الفيديو/الصوت واستخراج MP3).
- لو فشل تحميل من موقع معين: تأكد إن yt-dlp محدث لآخر إصدار: `pip install -U yt-dlp`.
- ملفات السجل موجودة في `logs/bot.log`، وبتدور تلقائيًا عند الوصول لـ 5MB.

## 📄 الرخصة

هذا المشروع مرخص تحت [MIT License](LICENSE).
