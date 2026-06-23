"""
bot.py - النسخة 2.1 (مصححة)
"""
from telegram import Update
from telegram.ext import (
    Application, CommandHandler, MessageHandler, CallbackQueryHandler,
    ContextTypes, filters,
)
from config import config
from database.models import db
from utils.logger import logger
from handlers import start, help as help_handler, settings, admin, download
from handlers import admin_dashboard, force_subscribe

async def on_error(update: object, context: ContextTypes.DEFAULT_TYPE):
    logger.error(f"حدث خطأ غير متوقع: {context.error}", exc_info=context.error)

async def post_init(application: Application):
    await db.connect()
    logger.info("✅ تم الاتصال بقاعدة البيانات بنجاح")

async def post_shutdown(application: Application):
    await db.close()
    logger.info("🔌 تم إغلاق الاتصال بقاعدة البيانات")

def main():
    config.validate()
    logger.info("🚀 بدء تشغيل البوت...")

    app = (
        Application.builder()
        .token(config.BOT_TOKEN)
        .post_init(post_init)
        .post_shutdown(post_shutdown)
        .build()
    )

    app.add_handler(CommandHandler("start", start.cmd_start))
    app.add_handler(CommandHandler("about", start.cmd_about))
    app.add_handler(CommandHandler("ping", start.cmd_ping))
    app.add_handler(CommandHandler("lang", start.cmd_lang))
    app.add_handler(CallbackQueryHandler(start.on_lang_callback, pattern="^setlang_"))
    app.add_handler(CommandHandler("help", help_handler.cmd_help))
    app.add_handler(CommandHandler("settings", settings.cmd_settings))
    app.add_handler(CommandHandler("stats", settings.cmd_stats))

    app.add_handler(CommandHandler("users", admin.cmd_users))
    app.add_handler(CommandHandler("botstats", admin.cmd_botstats))
    app.add_handler(CommandHandler("ban", admin.cmd_ban))
    app.add_handler(CommandHandler("unban", admin.cmd_unban))
    app.add_handler(CommandHandler("broadcast", admin.cmd_broadcast))
    app.add_handler(CommandHandler("logs", admin.cmd_logs))
    app.add_handler(CommandHandler("restart", admin.cmd_restart))
    app.add_handler(CommandHandler("update", admin.cmd_update))

    app.add_handler(CommandHandler("admin", admin_dashboard.cmd_admin))
    app.add_handler(CallbackQueryHandler(admin_dashboard.on_admin_callback, pattern="^admin_"))

    async def on_text_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
        pending_action = context.user_data.get("admin_action")
        if pending_action and await admin_dashboard.is_admin_check(update):
            await admin_dashboard.on_admin_text_input(update, context)
            return
        if not await force_subscribe.check_subscription(update, context):
            await force_subscribe.send_subscribe_message(update, context)
            return
        await download.on_message(update, context)

    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, on_text_message))
    app.add_handler(CallbackQueryHandler(download.on_download_callback, pattern="^dl"))

    app.add_error_handler(on_error)
    logger.info("✅ البوت شغال دلوقتي...")
    app.run_polling(allowed_updates=Update.ALL_TYPES)

if __name__ == "__main__":
    main()
