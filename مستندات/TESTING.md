# الاختبارات (Takween Testing)

## هدف المرحلة
ضمان ثبات سلوك MVP قبل التوسع في البناء الذكي ومدير الحزم.

## طبقات الاختبار
1. Parser Validation
2. CLI Contract
3. Check/Build/Run Flow
4. Clean Safety
5. Init Side Effects
6. Installer Smoke (Windows)

## حالات أساسية

### Parser
- ملف صحيح بالكامل -> نجاح.
- مفتاح غير مدعوم -> فشل.
- حقل إلزامي مفقود -> فشل.
- `التحسين` خارج المجال -> فشل.
- `ملفات` فارغة أو بلا `.baa` -> فشل.

### CLI
- أمر عربي صحيح -> الدالة الصحيحة تُستدعى.
- alias إنجليزي صحيح -> نفس السلوك.
- أمر غير معروف -> كود خروج `2`.

### Build/Run
- `تكوين check` -> `diagnostics-json-v1` صالح بلا تشخيصات لمشروع init.
- `تكوين build` مع ملف صحيح -> نجاح + توليد ملف الناتج.
- إعادة build -> `build-manifest.json` يسجل cache hit واحدا على الأقل.
- `تكوين run` -> ينفّذ البناء أولاً ثم يشغّل الناتج.
- إذا أعاد البرنامج الناتج كوداً غير صفري -> `تكوين run` يعيد نفس الكود.

### Clean Safety
- `المخرج: بناء/` -> يتم الحذف بنجاح.
- `المخرج: .` -> رفض التنظيف.
- `المخرج` يحتوي `..` -> رفض التنظيف.
- `المخرج` جذر نظام (`/` أو `C:\`) -> رفض التنظيف.

### Init
- إنشاء `المصدر/` إذا لم يوجد.
- إنشاء `مشروع.تكوين` قالب.
- إنشاء `المصدر/الرئيسية.baa` قالب.

### Installer (Inno Setup)
- تشغيل المثبت بنجاح بدون صلاحيات Admin.
- إضافة `{app}\bin` إلى PATH للمستخدم الحالي.
- إنشاء `TAKWEEN_HOME`.
- تنبيه المستخدم إذا `baa.exe` غير موجود في PATH.
- إزالة PATH entry عند uninstall.

## runner الآلي

يشغل `scripts/test_takween.ps1` بناء تكوين بمصرّف Baa محدد، ثم يتحقق من
help/version وinit/check/build/rebuild/run/clean، وعقود JSON والكاش، ورفض manifest
غير صالح والأعلام الحرة ومسار clean الخطر:

```powershell
.\scripts\test_takween.ps1 -BaaPath ..\Baa\build\presets\windows-verify\baa.exe
```

لا يعد الاختبار ناجحا إذا استخدم Baa مختلفا بصمت؛ يطبع runner المسار والإصدار.

## سيناريو المثبت (يدوي)
1. شغّل `scripts\build_installer.ps1`.
2. ثبّت النسخة الناتجة.
3. افتح Terminal جديد ونفّذ:
   - `تكوين --help`
   - `baa --version`
4. نفّذ `تكوين تهيئة` في مجلد فارغ.
5. نفّذ `تكوين build` ثم `تكوين run` وتحقق من التشغيل.
6. نفّذ `تكوين clean` وتحقق من حذف مخرجات البناء فقط.
7. ألغ التثبيت وتأكد من إزالة مسار Takween من PATH.

## البوابات التالية

- اختبارات parser بوحدات صغيرة بعد فصل النموذج عن globals.
- تشغيل runner نفسه على Windows وLinux بعد إزالة `cmd /c`.
- اختبار `test` وعقد reporter machine-readable موحد بعد إضافة هدف الاختبار.
