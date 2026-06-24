#!/data/data/com.termux/files/usr/bin/bash
# ~/.termux/boot/start_video_bot.sh
# يشتغل تلقائيًا لما الموبايل يولع (يحتاج تطبيق Termux:Boot مثبّت)

termux-wake-lock

# عدّل المسار ده لو مجلد البوت بتاعك في مكان مختلف
BOT_DIR="$HOME/storage/downloads/video_bot"

cd "$BOT_DIR" || exit 1

# يشغّل البوت جوه جلسة tmux اسمها videobot عشان تقدر توصله بعدين
tmux kill-session -t videobot 2>/dev/null
tmux new-session -d -s videobot "bash run.sh"

