# سياسة الإصدارات (Takween Versioning)

## القاعدة
Takween يستخدم **Semantic Versioning**:
- `MAJOR.MINOR.PATCH`

## سياسة الزيادة
- **MAJOR**: تغييرات كاسرة في CLI أو صيغة `مشروع.تكوين`.
- **MINOR**: ميزات جديدة متوافقة (مثال: build graph، دعم Linux).
- **PATCH**: إصلاحات أخطاء وتحسينات تشخيص بدون كسر العقد.

## علاقة الإصدار مع Baa
- كل إصدار Takween يجب أن يذكر نسخة Baa الدنيا المطلوبة.
- يذكر الإصدار مجال Baa المدعوم، لا نسخة بناء عارضة فقط.
- أي إصدار مدعوم يحتاج اختبار تكامل build/run وتشخيص JSON مثبتا.

## إصدار العقود

إصدار Takween منفصل عن إصدارات العقود:

- `takween-cli-v0`: CLI الحالي التجريبي.
- `takween-manifest-v0`: صيغة `مفتاح: قيمة` الحالية.
- `takween-manifest-v1`: الصيغة typed المخططة.
- `takween-lock-v1`: ملف القفل الحتمي المخطط.

تغيير schema كاسر يتطلب أداة ترحيل حتى إذا بقي Takween قبل 1.0.

## ملاحظات إصدار MVP
- أول إصدار MVP يثبت:
  - CLI contract
  - strict parser
  - init workflow

## سجل التغييرات
يحدّث `CHANGELOG.md` في كل تغيير عام أو معماري مع بيان تأثير العقود.
