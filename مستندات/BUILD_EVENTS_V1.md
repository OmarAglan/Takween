# عقد أحداث البناء v1

يعرّف `takween-build-events-v1` قناة مهيكلة بين تكوين وواجهات مثل قلم وCI.
القناة مستقلة عن `stdout` و`stderr`: يبقي تكوين المخرجات العربية البشرية كما هي،
ويكتب الأحداث إلى ملف يطلبه المستهلك صراحة.

## التفعيل والنقل

```text
تكوين بناء --ملف_أحداث <مسار>
تكوين فحص --ملف_أحداث <مسار>
تكوين تشغيل --ملف_أحداث <مسار>
تكوين اختبار --ملف_أحداث <مسار>
تكوين تنظيف --ملف_أحداث <مسار>
```

- `--events-file` alias توافق آلي فقط؛ الصيغة القياسية `--ملف_أحداث`.
- يرفض الخيار المكرر أو المسار المفقود بكود الاستخدام `2`.
- إذا تعذر إنشاء الملف أو فتحه يفشل تكوين بكود الأداة `4` قبل العملية.
- يفرغ تكوين الملف عند قبول الخيار، ثم يضيف كل حدث كسطر JSON كامل بترميز
  UTF-8 ويغلقه. لذلك يستطيع المستهلك قراءة السطور المكتملة أثناء العملية.
- لا يكتب تكوين JSONL إلى `stdout` أو `stderr`، ولا يخلط نص Baa أو البرنامج
  الناتج بالقناة المهيكلة.

## الغلاف المشترك

كل سطر كائن JSON مستقل بهذه الحقول الإلزامية:

| الحقل | النوع | المعنى |
|---|---|---|
| `schema_version` | string | ثابت: `takween-build-events-v1` |
| `sequence` | integer | يبدأ من `1` ويزداد واحدا داخل العملية |
| `event` | string | نوع الحدث |
| `operation` | string | `build`, `check`, `run`, `test`, أو `clean` |

الحقول الشرطية:

- `status`: إحدى `started`, `succeeded`, `failed`.
- `phase`: اسم المرحلة المستقر آليا.
- `exit_code`: عدد صحيح في أحداث النهاية.
- `target`: اسم الهدف في أحداث الاختبار.
- `package`: اسم حزمة مساحة العمل.
- `artifact`: كائن يحوي `kind` و`path` عند إنتاج أثر.

مثال:

```json
{"schema_version":"takween-build-events-v1","sequence":1,"event":"operation_started","operation":"build","phase":"operation","status":"started"}
{"schema_version":"takween-build-events-v1","sequence":2,"event":"phase_started","operation":"build","phase":"plan","status":"started"}
{"schema_version":"takween-build-events-v1","sequence":3,"event":"phase_finished","operation":"build","phase":"plan","status":"succeeded","exit_code":0}
{"schema_version":"takween-build-events-v1","sequence":4,"event":"artifact","operation":"build","artifact":{"kind":"executable","path":"بناء/تطبيقي.exe"}}
{"schema_version":"takween-build-events-v1","sequence":5,"event":"operation_finished","operation":"build","phase":"operation","status":"succeeded","exit_code":0}
```

## أنواع الأحداث

| `event` | الحقول الإضافية المطلوبة |
|---|---|
| `operation_started` | `phase="operation"`, `status="started"` |
| `operation_finished` | `phase="operation"`, `status`, `exit_code` |
| `phase_started` | `phase`, `status="started"` |
| `phase_finished` | `phase`, `status`, `exit_code` |
| `target_started` | `target`, `status="started"` |
| `target_finished` | `target`, `status`, `exit_code` |
| `package_started` | `package`, `status="started"` |
| `package_finished` | `package`, `status`, `exit_code` |
| `artifact` | `artifact.kind`, `artifact.path` |

أسماء المراحل الحالية تشمل `plan`, `prepare_output`, `compiler`,
`compiler_check`, `cache_receipt`, `build`, `program`, و`clean_output`.
لا يستنتج المستهلك النجاح من اسم المرحلة؛ يعتمد `status` و`exit_code`.

## الترتيب والنهاية

في الخروج الطبيعي:

1. `operation_started` هو السطر الأول.
2. كل `phase/target/package_started` المنفذ له حدث `finished` لاحق بالهوية نفسها.
3. آثار العملية تقع بعد المرحلة التي أنتجتها وقبل نهاية العملية.
4. `operation_finished` هو السطر الأخير والوحيد من نوعه، ويحمل كود تكوين النهائي.

قد يحمل `run` و`test` كود البرنامج بعد نجاح البناء؛ لذلك يبقى اسم المرحلة جزءا
من التصنيف ولا يجوز تفسير كل كود غير صفري على أنه خطأ مصرّف.

## الإلغاء والانقطاع

الإصدار v1 لا يعد بحدث نهائي إذا أنهى نظام التشغيل العملية قسرا. إذا كان
المستهلك هو من طلب الإلغاء ثم انتهت العملية دون `operation_finished`، يجوز له
إنشاء حالة واجهة محلية `cancelled`. دون طلب إلغاء، غياب الحدث النهائي فشل process
أو خرق للعقد ولا يعد نجاحا. سيضاف إلغاء تعاوني منتج داخل تكوين في تطوير لاحق
دون تغيير معنى الأحداث الحالية.

## التوافق

- يجوز إضافة حقول اختيارية إلى كائنات v1، وعلى المستهلك تجاهل ما لا يعرفه.
- لا يجوز تغيير معنى حقل أو حذف حقل مطلوب أو إعادة استخدام اسم حدث بمعنى آخر.
- أي تغيير كاسر يتطلب `takween-build-events-v2` وخيار تفاوض صريح.
