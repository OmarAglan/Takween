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
7. Typed Manifest + Path/Pinned-Git Dependencies + Lock Determinism

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
- عدم تمرير أمر -> كود خروج `2`.
- أمر غير معروف -> كود خروج `2`.
- هدف/نوع معروف غير مدعوم -> كود خروج `3`.
- Baa مزيف يعيد كل كود من `1` إلى `5` -> تحافظ أوامر check/build/run/test على
  الكود نفسه ولا تحوله إلى `1`.

### Build/Run
- `تكوين check` -> `diagnostics-json-v1` صالح بلا تشخيصات لمشروع init.
- `تكوين build` مع ملف صحيح -> نجاح + توليد ملف الناتج.
- إعادة build -> `build-manifest.json` يسجل cache hit واحدا على الأقل.
- `تكوين run` -> ينفّذ البناء أولاً ثم يشغّل الناتج.
- إذا أعاد البرنامج الناتج كوداً غير صفري -> `تكوين run` يعيد نفس الكود.

### `takween-manifest-v1`
- القيم quoted/int/bool/string-array والأقسام المعروفة -> نجاح.
- مفتاح/قسم/نوع قيمة مجهول -> فشل واضح.
- أهداف متعددة + مصادر متعددة + include paths -> يختار الهدف المطلوب وتدخل ملفاته خطة Baa.
- اعتمادية `المسار` ذات بيان v1 -> تدخل مصادرها وتضميناتها خطة check/build/run.
- اعتمادية Git بـ commit دقيق -> checkout معنون بالـ commit وتدخل مصادرها الخطة.
- Git branch/tag أو خلط path/Git -> رفض manifest قبل التنفيذ.
- حزمة Git ذات path متعدية -> العقدتان تظهران مع parent صحيح في `takween-lock-v1`.
- إزالة source Git بعد أول resolution -> rebuild/run ينجحان من cache وحده.
- تشغيل resolver مرتين -> SHA-256 لبايتات `تكوين.قفل` لا يتغير ولا يحوي CRLF.
- output يحوي مسافة و`&` -> يبنى ويعمل وينظف دون تفسير shell.

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
help/version وinit/check/build/rebuild/run/clean، وعقود JSON والكاش، وحدود argv،
وبيان v1 واعتماديات path/Git والقفل الحتمي، ورفض manifest غير صالح والأعلام الحرة
ومسار clean الخطر. كما يبني Baa مزيفا لكل كود `compiler-cli-v1` من `1` إلى `5`
ويثبت مروره كما هو عبر check/build/run/test:

```powershell
.\scripts\test_takween.ps1 -BaaPath ..\Baa\build\presets\windows-verify\baa.exe
```

لا يعد الاختبار ناجحا إذا استخدم Baa مختلفا بصمت؛ يطبع runner المسار والإصدار.

الrunner يستخدم `IO.Path.PathSeparator` ولا يحتوي مسار تنفيذ Windows خاصا، لذا
هو نفسه عقد Windows/Linux. إيصال GitHub Actions رقم
[29251889635](https://github.com/OmarAglan/Takween/actions/runs/29251889635)
بتاريخ 2026-07-13 شغّل الملف نفسه عبر `pwsh` ونجح على
`windows-latest` و`ubuntu-latest`، بما في ذلك اعتماديات Git المثبتة والقفل الحتمي.

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
- يتحقق runner من `target-info-v1` ومن أن اسم ناتج Takween وناتج المشروع يستخدمان
  لاحقة التنفيذ التي أعلنها Baa للمضيف.
- يشغل `.github/workflows/ci.yml` runner نفسه على `windows-latest` و`ubuntu-latest`
  بعد بناء Baa بإعداد CI القياسي نفسه.
- يغطي fixture متعدد الأهداف عقد `takween-targets-v1` واختيار build/run وهدف اختبار
  واحد وتشغيل كل أهداف الاختبار ورفض الهدف المفقود ونوع المكتبة غير المدعوم.
- ينشئ runner مستودع Git محليا بلا شبكة، ويثبت HEAD، ويتحقق من checkout المتعدي
  وإعادة الاستخدام بعد نقل المصدر وثبات lock bytes ورفض moving refs.
