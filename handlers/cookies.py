"""
handlers/cookies.py
أوامر الأدمن لإدارة الكوكيز:
- /check_cookies: فحص حالة كل ملفات الكوكيز (موجود/صالح/منتهي)
- /update_cookies: رفع ملف كوكيز جديد لمنصة معيّنة (عن طريق إرسال الملف كـ document بعد الأمر)
"""

from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import ContextTypes

from database.models import db
from utils.logger import logger
from utils.cookies_manager import check_all_platforms, save_cookie_file, PLATFORM_FILES

STATUS_LABELS = {
    "valid": "✅ صالح",
    "expired": "⏰ منتهي الصلاحية",
    "empty": "⚠️ فاضي/صيغة خاطئة",
    "missing": "❌ غير موجود",
}


async def is_admin_check(update: Update) -> bool:
    return await db.is_admin(update.effective_user.id)


async def cmd_check_cookies(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """فحص حالة الكوكيز لكل منصة معروفة"""
    if not await is_admin_check(update):
        await update.message.reply_text("🚫 <b>هذا الأمر للأدمن فقط.</b>", parse_mode="HTML")
        return

    results = check_all_platforms()

    lines = ["🍪 <b>حالة الكوكيز</b>\n"]
    for r in results:
        label = STATUS_LABELS.get(r["status"], r["status"])
        path_info = f" ({r['path']})" if r["path"] and r["status"] not in ("missing",) else ""
        lines.append(f"• {r['site']}: {label}{path_info}")

    lines.append(
        "\nلتحديث كوكيز منصة معيّنة استخدم:\n<code>/update_cookies اسم_المنصة</code>\n"
        "ثم ابعت ملف cookies.txt كـ Document في الرسالة اللي بعدها."
    )

    await update.message.reply_text("\n".join(lines), parse_mode="HTML")


async def cmd_update_cookies(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """بدء عملية رفع ملف كوكيز جديد لمنصة معيّنة"""
    if not await is_admin_check(update):
        await update.message.reply_text("🚫 <b>هذا الأمر للأدمن فقط.</b>", parse_mode="HTML")
        return

    if not context.args:
        keyboard = InlineKeyboardMarkup(
            [[InlineKeyboardButton(site, callback_data=f"cksite_{site}")] for site in PLATFORM_FILES]
        )
        await update.message.reply_text(
            "🍪 <b>اختر المنصة اللي عايز تحدّث كوكيزها:</b>",
            parse_mode="HTML",
            reply_markup=keyboard,
        )
        return

    site_input = " ".join(context.args)
    await _start_waiting_for_file(update, context, site_input)


async def on_cookie_site_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """معالجة اختيار المنصة من الأزرار"""
    query = update.callback_query
    await query.answer()

    if not await db.is_admin(query.from_user.id):
        await query.edit_message_text("🚫 <b>هذا الأمر للأدمن فقط.</b>", parse_mode="HTML")
        return

    site = query.data.replace("cksite_", "")
    if site not in PLATFORM_FILES:
        await query.edit_message_text("⚠️ منصة غير معروفة.")
        return

    context.user_data["awaiting_cookie_for"] = site
    await query.edit_message_text(
        f"📎 <b>تمام، دلوقتي ابعت ملف الكوكيز (cookies.txt) لـ {site} كـ Document.</b>",
        parse_mode="HTML",
    )


async def _start_waiting_for_file(update: Update, context: ContextTypes.DEFAULT_TYPE, site_input: str):
    matched = None
    for site in PLATFORM_FILES:
        if site.lower() == site_input.lower():
            matched = site
            break

    if not matched:
        sites_list = "، ".join(PLATFORM_FILES.keys())
        await update.message.reply_text(
            f"⚠️ <b>منصة غير معروفة.</b>\n\nالمنصات المتاحة: {sites_list}",
            parse_mode="HTML",
        )
        return

    context.user_data["awaiting_cookie_for"] = matched
    await update.message.reply_text(
        f"📎 <b>تمام، دلوقتي ابعت ملف الكوكيز (cookies.txt) لـ {matched} كـ Document.</b>",
        parse_mode="HTML",
    )


async def on_cookie_document(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """استقبال ملف الكوكيز المرفوع من الأدمن وحفظه في المنصة الصحيحة"""
    site = context.user_data.get("awaiting_cookie_for")
    if not site:
        return  # لا يوجد طلب تحديث كوكيز معلّق، تجاهل أي ملف عادي

    if not await db.is_admin(update.effective_user.id):
        return

    document = update.message.document
    if not document:
        return

    try:
        file = await context.bot.get_file(document.file_id)
        content = await file.download_as_bytearray()
        path = save_cookie_file(site, bytes(content))
        context.user_data.pop("awaiting_cookie_for", None)

        if path:
            await update.message.reply_text(
                f"✅ <b>تم حفظ كوكيز {site} بنجاح.</b>\n\nاستخدم /check_cookies للتأكد من الحالة.",
                parse_mode="HTML",
            )
            logger.info(f"تم تحديث كوكيز {site} من الأدمن {update.effective_user.id}")
        else:
            await update.message.reply_text("❌ فشل حفظ الملف.", parse_mode="HTML")

    except Exception as e:
        logger.error(f"فشل حفظ ملف كوكيز {site}: {e}")
        await update.message.reply_text(
            f"❌ <b>حصل خطأ أثناء حفظ الملف.</b>\n\n{e}", parse_mode="HTML"
        )
        context.user_data.pop("awaiting_cookie_for", None)

