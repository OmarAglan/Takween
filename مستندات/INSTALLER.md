# مثبت تكوين على ويندوز

## عقد التوزيع

ينتج تكوين حزمة مستقلة باسم
`takween-setup-0.1.0-x64.exe` وملف SHA-256 مجاور. لا تضم الحزمة باء أو نظم؛
تكتشفهما كأداتين مستقلتين من `PATH` عند بناء المشروع.

- التثبيت الافتراضي لكل مستخدمي الجهاز في `Program Files\Takween`.
- يقبل `/CURRENTUSER` للتثبيت في نطاق المستخدم دون صلاحيات مدير.
- يثبت `تكوين.exe` والأمر التوافقي `takween.exe` في `{app}\bin`.
- يضيف `{app}\bin` إلى PATH تلقائيا ويسجل ملكيته.
- يضبط `TAKWEEN_HOME` فقط إذا كان فارغا أو مملوكا لتثبيت تكوين سابق.
- لا يستدعي shell أثناء اكتشاف باء أو نظم.
- لا يحذف عند الإزالة إلا PATH والمتغيرات التي يملكها المثبت وتظل مساوية
  لمسارات التثبيت.

## متطلبات البناء

- باء 0.6.0 مع `target-info-v1` ومكتبة `baalib`.
- نظم المثبت أو المبني محليا.
- Inno Setup 6.

## بناء الحزمة

```powershell
.\scripts\build_installer.ps1 -Version 0.1.0 `
  -BaaPath C:\path\to\baa.exe `
  -BaaStdlibPath C:\path\to\stdlib `
  -NazmPath C:\path\to\nazm.exe
```

النواتج:

- `dist\bin\تكوين.exe`
- `dist\bin\takween.exe`
- `dist\installer\takween-setup-0.1.0-x64.exe`
- `dist\installer\takween-setup-0.1.0-x64.exe.sha256`

## بوابة دورة الحياة

```powershell
.\scripts\test_installer.ps1 `
  -BaaDirectory C:\path\to\baa-bin `
  -NazmDirectory C:\path\to\nazm-bin
```

تتحقق البوابة من التجزئة، والتثبيت في نطاق المستخدم، والأمرين العربي
والتوافقي، وملكية PATH و`TAKWEEN_HOME`، ثم تنشئ مشروعا في مسار عربي ذي
مسافات. تثبت أولا أن `تهيئة` تعمل دون أدوات خارجية وأن `بناء` يفشل
بتشخيص ظاهر عندما لا يكون باء ونظم متاحين. بعد ذلك تضيف الأداتين إلى
بيئة الاختبار وتنفذ `فحص` و`بناء` و`تشغيل` و`تنظيف`. أخيرا تزيل تكوين
وتتحقق من عدم بقاء ملفات أو حالة مملوكة.
