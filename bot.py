"""
bot.py - النسخة 2.3
- لوحة إدارة كاملة
- اختيار جودة دقيقة + جودة افتراضية
- Force Subscribe
- شريط تقدم
- قائمة أزرار ثابتة موسّعة (تحميلاتي الأخيرة، معلوماتي، تواصل مع الدعم، لوحة تحكم)
"""

from telegram import Update
from telegram.ext import (
    Application,
    CommandHandler,
    MessageHandler,
    CallbackQueryHandler,
    ContextTypes,
    filters,
)

from config import config
from database.models import db
from utils.logger import logger

from handlers import start, help as help_handler, settings, admin, download
from handlers import admin_dashboard, force_subscribe, menu


async def on_error(update: object, context: ContextTypes.DEFAULT_TYPE):
    logger.error(f"حدث خطأ غير متوقع: {context.error}", exc_info=context.error)


async def post_init(application: Application):
    await db.connect()
    logger.info("✅ تم الاتصال بقاعدة البيانات بنجاح")


async def post_shutdown(application: Application):
    await db.close()
    logger.info("🔌 تم إغلاق الاتصال بقاعدة البيانات")


async def cmd_cancel(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """إلغاء أي عملية معلّقة (دعم/برودكاست/حظر)"""
    context.user_data.pop("support_action", None)
    context.user_data.pop("admin_action", None)
    await update.message.reply_text("✅ <b>تم الإلغاء.</b>", parse_mode="HTML")


def main():
    config.validate()
    logger.info("🚀 بدء تشغيل البوت...")

    app = (
        Application.builder()
        .token(config.BOT_TOKEN)
        .connect_timeout(30)
        .read_timeout(30)
        .write_timeout(30)
        .pool_timeout(30)
        .post_init(post_init)
        .post_shutdown(post_shutdown)
        .build()
    )

    # ===== أوامر عامة =====
    app.add_handler(CommandHandler("start", start.cmd_start))
    app.add_handler(CommandHandler("about", start.cmd_about))
    app.add_handler(CommandHandler("ping", start.cmd_ping))
    app.add_handler(CommandHandler("lang", start.cmd_lang))
    app.add_handler(CommandHandler("cancel", cmd_cancel))
    app.add_handler(CallbackQueryHandler(start.on_lang_callback, pattern="^setlang_"))

    app.add_handler(CommandHandler("help", help_handler.cmd_help))

    app.add_handler(CommandHandler("settings", settings.cmd_settings))
    app.add_handler(CommandHandler("stats", settings.cmd_stats))

    # ===== أوامر الإدارة (القديمة) =====
    app.add_handler(CommandHandler("users", admin.cmd_users))
    app.add_handler(CommandHandler("botstats", admin.cmd_botstats))
    app.add_handler(CommandHandler("ban", admin.cmd_ban))
    app.add_handler(CommandHandler("unban", admin.cmd_unban))
    app.add_handler(CommandHandler("broadcast", admin.cmd_broadcast))
    app.add_handler(CommandHandler("logs", admin.cmd_logs))
    app.add_handler(CommandHandler("restart", admin.cmd_restart))
    app.add_handler(CommandHandler("update", admin.cmd_update))

    # ===== لوحة الإدارة الجديدة =====
    app.add_handler(CommandHandler("admin", admin_dashboard.cmd_admin))
    app.add_handler(
        CallbackQueryHandler(admin_dashboard.on_admin_callback, pattern="^admin_")
    )

    # ===== الجودة الافتراضية =====
    app.add_handler(CallbackQueryHandler(menu.on_quality_callback, pattern="^setq_"))

    # ===== معالج نصوص موحّد =====
    async def on_text_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
        # 1. المستخدم وسط كتابة رسالة دعم؟
        if context.user_data.get("support_action"):
            await _forward_support_message(update, context)
            return

        # 2. ضغطة على زر من القائمة الثابتة؟
        if await menu.is_menu_button(update):
            await menu.handle_menu_button(update, context)
            return

        # 3. الأدمن وسط عملية (برودكاست/حظر)؟
        pending_action = context.user_data.get("admin_action")
        if pending_action and await admin_dashboard.is_admin_check(update):
            await admin_dashboard.on_admin_text_input(update, context)
            return

        # 4. التحقق من Force Subscribe
        if not await force_subscribe.check_subscription(update, context):
            await force_subscribe.send_subscribe_message(update, context)
            return

        # 5. معالجة كرابط فيديو عادي
        await download.on_message(update, context)

    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, on_text_message))
    app.add_handler(CallbackQueryHandler(download.on_download_callback, pattern="^dl"))

    # ===== معالجة الأخطاء =====
    app.add_error_handler(on_error)

    logger.info("✅ البوت شغال دلوقتي...")
    app.run_polling(allowed_updates=Update.ALL_TYPES)


async def _forward_support_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """تحويل رسالة الدعم من المستخدم للأونر مباشرة"""
    context.user_data.pop("support_action", None)
    user = update.effective_user
    text = update.message.text

    try:
        await context.bot.send_message(
            chat_id=config.OWNER_ID,
            text=(
                f"📞 رسالة دعم جديدة\n\n"
                f"من: {user.first_name or ''} (@{user.username or '—'})\n"
                f"آيدي: {user.id}\n\n"
                f"الرسالة:\n{text}"
            ),
        )
        await update.message.reply_text(
            "✅ <b>تم إرسال رسالتك للدعم.</b>\n\nهيتم الرد عليك قريبًا.", parse_mode="HTML"
        )
    except Exception as e:
        logger.error(f"فشل تحويل رسالة الدعم: {e}")
        await update.message.reply_text(
            "❌ <b>حصل خطأ أثناء إرسال رسالتك.</b>\n\nحاول تاني.", parse_mode="HTML"
        )


if __name__ == "__main__":
    main()

