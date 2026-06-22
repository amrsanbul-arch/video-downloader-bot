# 🚀 خطوات رفع المشروع على GitHub (Termux)

## 1. فك الضغط وفتح المجلد
```bash
cd ~/storage/downloads   # أو المكان اللي نزلت فيه الملف المضغوط
unzip video-downloader-bot.zip
cd video_bot
```

## 2. إعداد Git (مرة واحدة فقط لو لسه معملتها)
```bash
git config --global user.name "amrsanbul-arch"
git config --global user.email "amrsanbul@gmail.com"
```

## 3. إنشاء الريبو على GitHub
- روح على https://github.com/new
- اسم الريبو مثلاً: `video-downloader-bot`
- سيبه Public أو Private حسب رغبتك
- **لا** تضيف README أو .gitignore من واجهة GitHub (موجودين بالفعل في المشروع)
- اضغط Create repository

## 4. ربط المجلد المحلي بالريبو ورفعه
```bash
git init
git add .
git commit -m "Initial commit - Video Downloader Bot"
git branch -M main
git remote add origin https://github.com/amrsanbul-arch/video-downloader-bot.git
git push -u origin main
```

> هيطلب منك Username و Password — استخدم **Personal Access Token (PAT)** بدل الباسورد العادي (GitHub بطل يقبل باسورد عادي). تقدر تعمل token من:
> Settings → Developer settings → Personal access tokens → Generate new token (صلاحية `repo` تكفي)

## 5. التأكد إن .env متعمل push (وهو مش المفروض يتعمل!)
ملف `.gitignore` already بيستثني `.env` تلقائيًا، يعني توكن البوت بتاعك **مش هيترفع** على GitHub. لو عايز تشغل المشروع بعد الكلون، انسخ `.env.example` وسمّيه `.env` واملأ بياناتك:
```bash
cp .env.example .env
nano .env
```

## 6. تثبيت المتطلبات وتشغيل البوت
```bash
pkg install ffmpeg -y   # لو لسه مش متثبت
pip install -r requirements.txt
python bot.py
```

## 🔄 في حالة عملت تعديلات بعد كده وعايز ترفعها تاني
```bash
git add .
git commit -m "وصف التعديل"
git push
```
