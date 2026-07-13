# سجل تغييرات تكوين

يتبع هذا الملف Semantic Versioning ويفصل إصدار تكوين عن إصدارات CLI والبيان
وملف القفل.

## غير مصدر

### أضيف

- `--إصدار/--version` مع فحص تطابق إصدار المصدر أثناء البناء.
- اختيار صريح لمسار Baa وstdlib في `build_takween.ps1`.
- runner آلي لـ help/version/init/build/run/clean وحالات الرفض الأساسية.
- تصميم `takween-manifest-v1` typed ومعمارية اعتماديات محلية أولا وملف قفل.
- `فحص/check` بتمرير مباشر لعقد `diagnostics-json-v1`.
- بناء incremental مع `.takween-cache` و`build-manifest.json` schema 1.
- Process API مهيكلة من Baa لـ argv/cwd/stdout/stderr/exit/cancel، مع إزالة
  `cmd /c` و`نفذ_أمر` من executor بالكامل.
- parser تلقائي لـ `takween-manifest-v1` بقيم نصية وصحيحة ومنطقية ومصفوفات نصوص،
  وأقسام المشروع/الهدف/البناء/النمط/الاعتماديات/مساحة العمل.
- اعتماديات `المسار` المحلية والمتعدية: قراءة بيان الحزمة، إضافة مصادرها ومسارات
  تضمينها إلى خطة Baa، كشف الدورات المباشرة، ومنع تكرار الحزمة في الرسم.
- fixtures smoke لـ v1 واعتمادية مسار ومخرجات تحوي مسافة و`&` ورفض مفتاح مجهول.
- أهداف v1 متعددة مع اختيار build/check/run، وأمر `test` لهدف واحد أو كل أهداف
  الاختبار، وعقد فهرسة `takween-targets-v1` لتكامل Qalam وCI.
- اعتماديات Git مثبتة بحقل `commit` exact، تُجلب وتُفحص عبر argv بلا shell وتخزن
  في `.takween/packages/<commit>` مع تعطيل checkout hooks والبروتوكولات غير المعتمدة.
- `takween-lock-v1` حتمي بـ UTF-8/LF للمشروع وهدف Baa وعقد path/Git المتعدية؛
  يغطي smoke ثبات البايتات وإعادة استخدام cache offline ورفض branch والمصدر المختلط.
- أكواد خروج موحدة مع `compiler-cli-v1` (`0` إلى `5`) وتمرير كود Baa كما هو عبر
  check/build/run/test، مع smoke مستقل لكل تصنيف على Windows وLinux.

### تغيّر

- تحديث خط أساس التكامل في مساحة Eco من Baa 0.4.4.1 إلى 0.6.0، وإثبات
  help/version/init/build/run/clean عبر runner ويندوز بمسارات عربية.
- جعل تضمين `تكوين.baahd` نسبيا إلى ملفات المصدر بدلا من الاعتماد على cwd.
- إعادة ترتيب الخارطة: build system متعدد المنصات، ثم manifest/DAG، ثم
  اعتماديات محلية وقفل، ثم سجل عام مؤجل.
- استبدال فلترة محارف shell بالحفاظ الحقيقي على حدود argv؛ تبقى فحوص اجتياز
  المسار والأعلام الحرة typed، ولا تعاد قراءة أي قيمة كأمر shell.

## 0.1.0 - 2026-03-03

- MVP خاص بويندوز: init وparser صارم وbuild/run/clean ومثبت Inno Setup.
