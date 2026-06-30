#!/data/data/com.termux/files/usr/bin/bash
# run.sh
# يشغّل البوت مع: فحص المتطلبات، تفعيل virtualenv (لو موجود)، إعادة تشغيل تلقائي عند الكراش
# مصمم للعمل بدون أي مشاكل على Termux/Android بدون الاعتماد على systemd

cd "$(dirname "$0")"

# ===== تفعيل virtualenv لو موجود (لأنظمة Linux/VPS فقط - على Termux غالبًا غير مستخدم) =====
if [ -f "venv/bin/activate" ]; then
    echo "🐍 تفعيل virtualenv..."
    source venv/bin/activate
fi

# ===== فحص بسيط للمتطلبات الأساسية قبل التشغيل =====
if ! command -v python >/dev/null 2>&1; then
    echo "❌ Python غير مثبّت أو غير موجود في PATH."
    exit 1
fi

if [ ! -f "bot.py" ]; then
    echo "❌ ملف bot.py غير موجود في هذا المجلد."
    exit 1
fi

if [ ! -f ".env" ]; then
    echo "⚠️ تحذير: ملف .env غير موجود. تأكد من إنشائه من .env.example قبل التشغيل."
fi

# ===== منع Android من إيقاف Termux في الخلفية =====
# يحتاج أيضًا: إعدادات الموبايل > التطبيقات > Termux > البطارية > بدون قيود (Unrestricted)
if command -v termux-wake-lock >/dev/null 2>&1; then
    termux-wake-lock
    echo "🔒 تم تفعيل termux-wake-lock (منع Android من إيقاف التطبيق في الخلفية)"
else
    echo "💡 لمنع Android من إيقاف البوت في الخلفية، ثبّت: pkg install termux-api"
fi

echo "🚀 بدء حلقة التشغيل الدائم للبوت..."
echo "(لإيقاف البوت نهائيًا: اضغط Ctrl+C مرتين بسرعة)"
echo ""

# ===== حلقة إعادة التشغيل التلقائي (بديل بسيط عن systemd، يعمل على أي بيئة Linux/Termux) =====
RESTART_COUNT=0
while true; do
    python bot.py
    EXIT_CODE=$?
    RESTART_COUNT=$((RESTART_COUNT + 1))
    echo ""
    echo "⚠️ البوت توقف (exit code: $EXIT_CODE). إعادة التشغيل رقم $RESTART_COUNT بعد 5 ثواني..."
    sleep 5
done

