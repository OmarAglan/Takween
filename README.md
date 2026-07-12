# تكوين (Takween)

> نظام البناء العربي الرسمي للغة **باء (Baa)**.
> 
> The Arabic-first build system for Baa.

## الحالة الحالية (Current Status)
- **آخر تحديث:** 2026-07-11
- **إصدار تكوين:** `0.1.0`.
- **خط أساس باء في مساحة Eco:** `0.6.0`؛ runner ‏init/check/build/run/test/clean/targets
  وبيان v1 واعتمادية المسار يمر بهذا المصرّف على Windows.
- **اتجاه المشروع:** استبدال سير عمل `CMake/Make` لمشاريع Baa بواجهة أبسط (`تكوين ...`).
- **وضع تكوين:** parser متوافق مع صيغة 0.1 ومع `takween-manifest-v1` متعدد الأهداف؛
  check/build/run/test/clean يستخدم Process API مهيكلة من Baa بلا shell، مع بناء
  incremental واعتماديات مسار محلية واكتشاف هدف المضيف عبر `target-info-v1`.
- **الاعتمادات:** لا توجد `stdlib` محلية داخل Takween؛ يتم الاعتماد على `baalib.baahd` من تثبيت Baa.
- **الحزم:** تصميم محلي/حتمي أولا؛ لا يوجد سجل حزم عام في 0.1.

## لماذا تكوين؟
- واجهة أوامر عربية مباشرة لمشاريع Baa.
- ملف 0.1 بسيط أو بيان v1 typed بأقسام وقيم نص/صحيح/منطقي/مصفوفة نصوص.
- نهج صارم في التحقق المبكر من الأخطاء.
- تثبيت سهل للمستخدم النهائي (Installer + PATH) على ويندوز.

## التثبيت للمستخدم النهائي (Windows)
1. شغّل مثبت Takween (`takween-setup-<version>.exe`).
2. فعّل خيار إضافة Takween إلى PATH أثناء التثبيت.
3. تأكد بعد التثبيت:

```powershell
تكوين --help
baa --version
```

> تكوين يعتمد على وجود `baa` في PATH وعلى عقد `--target-info=json` من Baa.

## بناء المثبت (للمطورين)
نستخدم **Inno Setup Compiler** لبناء مثبت ويندوز:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build_installer.ps1 -Version 0.1.0
```

لبناء binary مباشرة بمصرّف محدد وقابل لإعادة الإنتاج:

```powershell
.\scripts\build_takween.ps1 -Version 0.1.0 -BaaPath C:\path\to\baa.exe -BaaStdlibPath C:\path\to\stdlib
```

- الملف الناتج: `dist\installer\takween-setup-<version>.exe`
- إذا كان `ISCC.exe` خارج المسار الافتراضي، مرره صراحة عبر `-IsccPath`.

## أوامر CLI (MVP)
```powershell
تكوين تهيئة      # init
تكوين فحص        # check, diagnostics-json-v1
تكوين بناء       # build
تكوين تشغيل      # run
تكوين اختبار     # test: تشغيل كل أهداف الاختبار
تكوين أهداف --json # targets: takween-targets-v1
تكوين تنظيف      # clean
تكوين --إصدار    # version
```

> يوجد alias متوافق: `takween`.

يبني `تكوين بناء` مباشرة إلى مجلد المخرجات، ويستخدم كاش Baa incremental تحت
`المخرج/.takween-cache`، ويكتب `المخرج/build-manifest.json`. الحقول الحرة مثل
`أعلام_إضافية` مرفوضة تنفيذيا حتى تستبدل بخيارات typed.

يُكتشف v1 عندما يبدأ أول سطر فعال بقسم `[ ... ]`. يدعم التنفيذ الحالي عدة أهداف
`تنفيذي/اختبار/مكتبة`، واختيار الهدف في build/check/run، وتشغيل هدف اختبار واحد أو
كل أهداف الاختبار، وبناء/نمطا typed واعتماديات `[الاعتماديات.<اسم>] المسار = "..."`
المتعدية. نوع المكتبة ظاهر في الفهرس لكنه غير قابل للبناء بعد؛ وتبقى globs وGit/registry
وملف القفل مراحل لاحقة.

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
- [سجل التغييرات](CHANGELOG.md)
- [صيغة البيان v1 وحالة التنفيذ](مستندات/MANIFEST_V1.md)
- [معمارية الحزم والقفل](مستندات/PACKAGES.md)
- [دليل المثبت](مستندات/INSTALLER.md)

## الارتباط بمشروع Baa
- المستودع الأساسي: <https://github.com/OmarAglan/Baa>
- يتم اعتماد مواصفات Baa من المصدر الرسمي مباشرة.

