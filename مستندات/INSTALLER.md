# Installer Guide (Windows)

## الهدف
توفير تجربة تثبيت سهلة لمستخدمي Takween على ويندوز بدون إعدادات يدوية معقدة.

## متطلبات البناء
- Baa compiler (`baa.exe`) في PATH
- Inno Setup 6 (`ISCC.exe`)

## بناء ثنائي Takween
```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build_takween.ps1 -Version 0.1.0
```

## بناء المثبت
```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build_installer.ps1 -Version 0.1.0
```

إذا كان `ISCC.exe` خارج المسار الافتراضي:
```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build_installer.ps1 -Version 0.1.0 -IsccPath "C:\path\to\ISCC.exe"
```

## الناتج
- `dist\bin\تكوين.exe` (primary)
- `dist\bin\takween.exe` (alias)
- `dist\installer\takween-setup-<version>.exe`

## سلوك المثبت
- يثبت Takween في `{localappdata}\Programs\Takween`
- يضيف `{app}\bin` إلى PATH للمستخدم الحالي (اختياري Task)
- ينشئ متغير البيئة `TAKWEEN_HOME`
- يعرض تنبيهاً إذا `baa.exe` غير موجود في PATH
- يزيل PATH entry و`TAKWEEN_HOME` عند إلغاء التثبيت
