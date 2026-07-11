# اختبارات تكوين

## Smoke آلي

من جذر المستودع:

```powershell
.\scripts\test_takween.ps1 -BaaPath <path-to-baa.exe>
```

يغطي runner:

- `--help` و`--version`؛
- `init` وإنشاء الملفين؛
- build/run والخرج المتوقع؛
- clean وحذف مجلد البناء فقط؛
- رفض مفتاح مجهول؛
- رفض `المخرج: .` في clean.

## لاحقا

يبقى فصل parser إلى API قابلة لاختبارات وحدات، وإضافة Linux، واختبارات عقود
JSON/build-manifest ضمن خارطة 0.2.
