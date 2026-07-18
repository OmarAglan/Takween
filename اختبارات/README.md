# اختبارات تكوين

## Smoke آلي

من جذر المستودع:

```powershell
.\scripts\test_takween.ps1 `
  -BaaPath <path-to-baa.exe> `
  -NazmPath <path-to-nazm.exe>
```

يغطي runner:

- `--help` و`--version`؛
- `init` وإنشاء الملفين؛
- build/run والخرج المتوقع؛
- `takween-build-plan-v1` الحتمي وعدم تنفيذ المصرّف أثناء التخطيط؛
- تثبيت `غاز` افتراضيا والحفاظ على اختيار `نظم` في الخطة؛
- DAG أهداف dependency-first وربط مكتبة انتقائيا وكشف الدورة بمسارها الكامل؛
- رفض هدف مفقود أو edge غير مكتبة أو هوية هدف غير عربية؛
- 200 قراءة متتابعة لعقد الأهداف لإثبات ملكية نصوص parser وثبات JSON؛
- clean وحذف مجلد البناء فقط؛
- رفض مفتاح مجهول؛
- رفض `المخرج: .` في clean.

يغطي runner كذلك عقود v1 والأهداف المتعددة واعتماديات path/Git/SemVer والأرشيف
والقفل والتوريد وأكواد `compiler-cli-v1`. تشغله CI على Windows وLinux.
