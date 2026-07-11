# سجل تغييرات تكوين

يتبع هذا الملف Semantic Versioning ويفصل إصدار تكوين عن إصدارات CLI والبيان
وملف القفل.

## غير مصدر

### أضيف

- `--إصدار/--version` مع فحص تطابق إصدار المصدر أثناء البناء.
- اختيار صريح لمسار Baa وstdlib في `build_takween.ps1`.
- runner آلي لـ help/version/init/build/run/clean وحالات الرفض الأساسية.
- تصميم `takween-manifest-v1` typed ومعمارية اعتماديات محلية أولا وملف قفل.

### تغيّر

- تحديث خط أساس التكامل في مساحة Eco من Baa 0.4.4.1 إلى 0.6.0، وإثبات
  help/version/init/build/run/clean عبر runner ويندوز بمسارات عربية.
- جعل تضمين `تكوين.baahd` نسبيا إلى ملفات المصدر بدلا من الاعتماد على cwd.
- إعادة ترتيب الخارطة: build system متعدد المنصات، ثم manifest/DAG، ثم
  اعتماديات محلية وقفل، ثم سجل عام مؤجل.

## 0.1.0 - 2026-03-03

- MVP خاص بويندوز: init وparser صارم وbuild/run/clean ومثبت Inno Setup.
