FROM python:3.11-slim

# تثبيت ffmpeg المطلوب لـ yt-dlp لدمج الفيديو والصوت واستخراج MP3
RUN apt-get update && \
    apt-get install -y --no-install-recommends ffmpeg git && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

RUN mkdir -p downloads logs

CMD ["python", "bot.py"]
