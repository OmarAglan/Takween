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
7. Typed Manifest + Path/Pinned-Git/Local-Archive Dependencies + Lock Determinism
8. SemVer + SHA-256 + Locked/Offline Resolution
9. Bounded Archive Extraction + Deterministic Vendoring + Arabic Identity

## حالات أساسية

### Parser
- ملف صحيح بالكامل -> نجاح.
- مفتاح غير مدعوم -> فشل.
- حقل إلزامي مفقود -> فشل.
- `التحسين` خارج المجال -> فشل.
- `ملفات` فارغة أو بعنصر لا ينتهي بـ`.baa` أو `.نظم` -> فشل.

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
- هدف مختلط `.baa`/`.نظم` مع `المجمع = "نظم"` -> يبني ويعمل عبر الأمر العربي
  `نظم` على `PATH`، ويثبت build-manifest وحدتي `baa` و`nazm` ومجمع `nazm`.
- `check` للهدف المختلط -> يحافظ على كود غير مدعوم `3` إلى أن يوجد JSON تشخيصي لنظم.
- اعتمادية `المسار` ذات بيان v1 -> تدخل مصادرها وتضميناتها خطة check/build/run.
- اعتمادية Git بـ commit دقيق -> checkout معنون بالـ commit وتدخل مصادرها الخطة.
- Git branch/tag أو خلط path/Git -> رفض manifest قبل التنفيذ.
- حزمة Git ذات path متعدية -> العقدتان تظهران مع parent صحيح في `takween-lock-v1`.
- إزالة source Git بعد أول resolution -> rebuild/run ينجحان من cache وحده.
- تشغيل resolver مرتين -> SHA-256 لبايتات `تكوين.قفل` لا يتغير ولا يحوي CRLF.
- فهرس محلي بترتيب غير مصنف وإصدارات متوافقة/غير متوافقة -> يختار أعلى SemVer
  مطابق حتميا، مع tie-break ثابت لـ build metadata المتساوية في precedence.
- تعديل archive بعد القفل -> يرفض `--locked` SHA-256 ولا يبدل القفل.
- تعديل البيان بعد القفل -> يرفض `--locked` القفل القديم ويحذف مرشح المقارنة.
- إزالة أي مجال مطابق -> تعارض SemVer صريح.
- محتوى cache معنون بـ SHA-256 ومصدر الفهرس بلا شبكة -> build/run ينجحان offline.
- `تحقق --بدون_شبكة` مع cache سليم وقفل مطابق -> نجاح بلا إصلاح أو جلب.
- تعديل ملف داخل cache -> التحقق دون شبكة يرفض؛ الحل العادي يعيد الاستخراج من
  الأرشيف immutable ثم ينجح التحقق.
- `توريد` مرتين -> شجرة `مورد/<اسم>/<إصدار>/<sha256>` وتجزئات كل ملفاتها متطابقة.
- absolute path أو `..` أو سجل link أو مسار مكرر/متصادم أو غير مرتب -> فشل ولا
  تبقى شجرة cache مرشحة.
- حجم ملف فوق 8 MiB أو مجموع/عدد غير مطابق أو SHA-256 داخلي خاطئ -> فشل محدود.
- قيد Baa للجذر أو الحزمة غير مطابق، أو target غير موجود، أو قدرة build ناقصة
  -> كود غير مدعوم واضح.
- اسم مشروع/حزمة/alias لاتيني -> رفض بعقد الهوية العربية فقط.
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
وبيان v1 واعتماديات path/Git/archive وSemVer وSHA-256 و`--locked` والقفل الحتمي،
وفك الأرشيف المحدود والتوريد والتحقق دون شبكة والهوية العربية وقيود Baa/target،
ورفض manifest غير صالح والأعلام الحرة
ومسار clean الخطر. كما يبني Baa مزيفا لكل كود `compiler-cli-v1` من `1` إلى `5`
ويثبت مروره كما هو عبر check/build/run/test:

```powershell
.\scripts\test_takween.ps1 `
  -BaaPath ..\Baa\build\presets\windows-verify\baa.exe `
  -NazmPath ..\Nazm\build\eco-verify\nazm.exe
```

لا يعد الاختبار ناجحا إذا استخدم Baa مختلفا بصمت؛ يطبع runner المسار والإصدار.

الrunner يستخدم `IO.Path.PathSeparator` ولا يحتوي مسار تنفيذ Windows خاصا، لذا
هو نفسه عقد Windows/Linux. إيصال GitHub Actions رقم
[29258386560](https://github.com/OmarAglan/Takween/actions/runs/29258386560)
بتاريخ 2026-07-13 شغّل الملف نفسه عبر `pwsh` ونجح على
`windows-latest` و`ubuntu-latest`، بما في ذلك اعتماديات Git المثبتة والقفل الحتمي
وتمرير كل كود `compiler-cli-v1` من `1` إلى `5` عبر check/build/run/test.

## سيناريو المثبت (يدوي)
1. شغّل `scripts\build_installer.ps1`.
2. ثبّت النسخة الناتجة.
3. افتح Terminal جديد ونفّذ:
   - `تكوين --مساعدة`
   - `baa --version`
4. نفّذ `تكوين تهيئة` في مجلد فارغ.
5. نفّذ `تكوين بناء` ثم `تكوين تشغيل` وتحقق من التشغيل.
6. نفّذ `تكوين تنظيف` وتحقق من حذف مخرجات البناء فقط.
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
