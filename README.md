# تكوين (Takween)

> نظام البناء العربي الرسمي للغة **باء (Baa)**.
> 
> The Arabic-first build system for Baa.

## الحالة الحالية (Current Status)
- **آخر تحديث:** 2026-03-02
- **اعتماد باء:** المتطلبات الأساسية لتكوين متاحة في Baa `v0.4.4.1`.
- **اتجاه المشروع:** استبدال سير عمل `CMake/Make` لمشاريع Baa بواجهة أبسط (`takween ...`).
- **وضع تكوين:** MVP قيد التنفيذ (تهيئة + parser صارم + build فعلي من `مشروع.تكوين` + مسار توزيع Windows عبر Inno Setup).
- **الاعتمادات:** لا توجد `stdlib` محلية داخل Takween؛ يتم الاعتماد على `baalib.baahd` من تثبيت Baa.

## لماذا تكوين؟
- واجهة أوامر عربية مباشرة لمشاريع Baa.
- ملف إعداد بسيط بصيغة `مفتاح: قيمة`.
- نهج صارم في التحقق المبكر من الأخطاء.
- تثبيت سهل للمستخدم النهائي (Installer + PATH) على ويندوز.

## التثبيت للمستخدم النهائي (Windows)
1. شغّل مثبت Takween (`takween-setup-<version>.exe`).
2. فعّل خيار إضافة Takween إلى PATH أثناء التثبيت.
3. تأكد بعد التثبيت:

```powershell
takween --help
baa --version
```

> Takween يعتمد على وجود `baa.exe` في PATH.

## بناء المثبت (للمطورين)
نستخدم **Inno Setup Compiler** لبناء مثبت ويندوز:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build_installer.ps1 -Version 0.1.0
```

- الملف الناتج: `dist\installer\takween-setup-<version>.exe`
- إذا كان `ISCC.exe` خارج المسار الافتراضي، مرره صراحة عبر `-IsccPath`.

## أوامر CLI (MVP)
```powershell
takween تهيئة    # init
takween بناء     # build
takween تشغيل    # run
takween تنظيف    # clean
```

## مثال `مشروع.تكوين` (MVP)
```text
الاسم: تطبيقي_الأول
الإصدار: 1.0.0
النوع: تنفيذي
المصدر: المصدر/
المخرج: بناء/
ملفات: الرئيسية.baa
التحسين: ١
```

## التوثيق
- [خارطة الطريق](ROADMAP.md)
- [صيغة الملف](مستندات/FORMAT.md)
- [عقد CLI](مستندات/CLI.md)
- [المعمارية](مستندات/ARCHITECTURE.md)
- [المساهمة](مستندات/CONTRIBUTING.md)
- [الاختبارات](مستندات/TESTING.md)
- [الإصدارات](مستندات/VERSIONING.md)
- [دليل المثبت](مستندات/INSTALLER.md)

## الارتباط بمشروع Baa
- المستودع الأساسي: <https://github.com/OmarAglan/Baa>
- يتم اعتماد مواصفات Baa من المصدر الرسمي مباشرة.

