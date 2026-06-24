#!/data/data/com.termux/files/usr/bin/bash
# run.sh
# يشغّل البوت، ولو كرّش لأي سبب يعيد تشغيله تلقائيًا بعد 5 ثواني
# يفضل يحاول طول ما إنت ضاغط Ctrl+C يدوي بس

cd "$(dirname "$0")"

# يمنع Android يوقف Termux في الخلفية (يحتاج إذن "Disable battery optimization" كمان)
termux-wake-lock 2>/dev/null

echo "🚀 بدء حلقة التشغيل الدائم للبوت..."
echo "(لإيقاف البوت نهائيًا: اضغط Ctrl+C مرتين بسرعة)"
echo ""

while true; do
    python bot.py
    EXIT_CODE=$?
    echo ""
    echo "⚠️ البوت توقف (exit code: $EXIT_CODE). إعادة التشغيل بعد 5 ثواني..."
    sleep 5
done

