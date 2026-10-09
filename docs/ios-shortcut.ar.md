<div dir="rtl">

# KFUPM Sorter على iPhone وiPad وMac

[English](ios-shortcut.md)

يعمل KFUPM Sorter على أجهزة Apple بوصفه **اختصارًا** في تطبيق «الاختصارات» (Shortcuts). وهو يؤدي عمل نسخة Windows نفسه: ينقل الملفات الموجودة في مجلد **Downloads** إلى مجلد يحمل اسم المقرر (`COE 301` و`EE 236` ...) أو اسم فلتر مخصص (`Internship` ...)، ويرتب ما سوى ذلك حسب نوعه (`Documents` و`Images` و`Videos` ...).

لا يحذف أي ملف، ولا يرسل أي بيانات إلى أي جهة. والاتصال الوحيد بالإنترنت يكون عند اختيار المقررات، إذ يُنزَّل دليل المقررات العام من هذا المستودع.

---

## الطريقة الأولى: التثبيت بلمسة واحدة (الأسهل)

1. افتح زر **Get the Shortcut** في [صفحة التنزيل](https://kal429.github.io/kfupm-sorter/) من جهاز iPhone أو iPad. (إن ظهر على الزر «قريبًا» فاتبع الطريقة الثانية حاليًا.)
2. اضغط **Add Shortcut** (إضافة الاختصار).
3. افتح تطبيق الاختصارات واضغط **KFUPM Sorter** مرة واحدة، وسيطلب منك اختيار مجلد **Downloads** (iCloud Drive ← Downloads)، ثم تظهر القائمة.
4. اختر **Pick my courses** وحدد مقرراتك (استعمل شريط البحث، مثل `coe 301`).
5. فعّل الترتيب التلقائي كما في قسم [التشغيل التلقائي](#التشغيل-التلقائي).

تُزامَن الاختصارات عبر iCloud، فيظهر الاختصار نفسه على iPad وMac أيضًا.

---

## الطريقة الثانية: بناء الاختصار بنفسك (نحو 15 دقيقة)

لا تسمح Apple بمشاركة الاختصارات إلا عبر روابط iCloud، ولذلك بُني الاختصار السابق يدويًا في تطبيق الاختصارات. وهذه هي الخطوات بالتفصيل لمن أراد بناء نسخته أو تعديلها.

> أسماء الإجراءات أدناه هي أسماؤها بالإنجليزية. إن كانت لغة جهازك العربية فابحث عن الإجراءات نفسها بأيقوناتها، أو غيّر لغة الجهاز إلى الإنجليزية مؤقتًا أثناء البناء.

### الملفات التي يستعملها

يحفظ الاختصار ملفين نصيين صغيرين في **iCloud Drive ← Shortcuts ← KFUPM Sorter**:

</div>

| File | One line per rule | Example |
|---|---|---|
| `courses.txt` | `FOLDER\|PATTERN` | `COE 301\|COE[\s_-]*301(?!\d)` |
| `filters.txt` | `FOLDER\|PATTERN` | `Internship\|(?<!\p{L})coop(?!\p{L})` |

<div dir="rtl">

لا حاجة إلى تعديلهما يدويًا، فالقائمة تكتبهما. ونمط `COE 301` يطابق أيضًا `COE301` و`coe_301` و`COE-301`، ولا يطابق `COE 3011`. أما الكلمة المفتاحية في الفلتر المخصص فتُطابَق كلمةً كاملة، فكلمة `lab` تطابق `Lab 3 Report.pdf`، ولا تطابق `Syllabus.pdf`.

### خطوات البناء

أنشئ اختصارًا جديدًا باسم **KFUPM Sorter**. ومن تفاصيله (زر **ⓘ**) اجعل **Receive** (الاستقبال) من النوع **Text**، ليتمكن التشغيل التلقائي من تمرير كلمة `auto` إليه.

أضف الإجراءات الآتية بالترتيب، والإجراءات المتفرعة توضع داخل الكتلة التي فوقها.

**الجزء (أ): مجلد التنزيلات**

1. **File**: اضغط حقل الملف واختر مجلد **Downloads** (iCloud Drive ← Downloads، حيث يحفظ Safari الملفات).
2. **Set Variable** باسم `Downloads` وقيمته الملف السابق.

**الجزء (ب): القائمة (تظهر فقط عند فتح الاختصار يدويًا)**

3. **If** `Shortcut Input` **does not have any value**
4. **Choose from Menu** بعنوان `KFUPM Sorter` وأربعة خيارات: `Sort now` و`Pick my courses` و`Add a custom filter` و`Clear custom filters`.
5. تحت **Sort now**: لا شيء (اتركه فارغًا).
6. تحت **Pick my courses**:
   1. **Get Contents of URL**: `https://raw.githubusercontent.com/kal429/kfupm-sorter/main/ios/courses.txt`
   2. **Split Text** حسب **New Lines**.
   3. **Choose from List** بعنوان `Pick your courses` مع تفعيل **Select Multiple**.
   4. **Repeat with Each** لكل عنصر مختار:
      1. **Split Text** للعنصر `Repeat Item` حسب **Custom** بالقيمة ` - ` (مسافة ثم شرطة ثم مسافة).
      2. **Get Item from List**: **First Item**.
      3. **Set Variable** باسم `Code`.
      4. **Replace Text**: ابحث عن ` ` (مسافة واحدة) واستبدلها بـ `[\s_-]*` في `Code`، مع إبقاء **Regular Expression** معطّلًا.
      5. **Text**: `Code` ثم `|` ثم `Updated Text` ثم `(?!\d)` متتالية دون مسافات.
      6. **Add to Variable** باسم `CourseLines`.
   5. **End Repeat**
   6. **Combine Text** للمتغير `CourseLines` باستعمال **New Lines**.
   7. **Save File**: عطّل **Ask Where to Save**، واختر الوجهة **Shortcuts** والمسار `KFUPM Sorter/courses.txt`، وفعّل **Overwrite If File Exists**.
   8. **Show Notification**: `Courses saved`.
   9. **Stop This Shortcut**.
7. تحت **Add a custom filter**:
   1. **Ask for Input** (نص) بالسؤال `Folder name, for example Internship`، ثم **Set Variable** باسم `FilterFolder`.
   2. **Ask for Input** (نص) بالسؤال `Keywords, separated by commas`.
   3. **Split Text** حسب **Custom** بالقيمة `,`.
   4. **Repeat with Each**:
      1. **Replace Text**: ابحث عن `^\s+|\s+$` واستبدله بلا شيء في `Repeat Item`، مع تفعيل **Regular Expression**.
      2. **If** `Updated Text` **has any value**:
         1. **Text**: `FilterFolder` ثم `|(?<!\p{L})` ثم `Updated Text` ثم `(?!\p{L})`
         2. **Add to Variable** باسم `FilterLines`.
      3. **End If**
   5. **End Repeat**
   6. **Get File from Folder**: `KFUPM Sorter/filters.txt` في **Shortcuts**، مع تعطيل **Error If Not Found**.
   7. **Get Text from Input** للملف، ثم **Set Variable** باسم `OldFilters`.
   8. **Combine Text** للمتغير `FilterLines` باستعمال **New Lines**.
   9. **Text**: `OldFilters` ثم سطر جديد ثم `Combined Text`.
   10. **Save File**: عطّل Ask Where to Save، والوجهة **Shortcuts**، والمسار `KFUPM Sorter/filters.txt`، مع تفعيل Overwrite.
   11. **Show Notification**: `Filter saved`، ثم **Stop This Shortcut**.
8. تحت **Clear custom filters**:
   1. **Get File from Folder**: `KFUPM Sorter/filters.txt` في **Shortcuts**، مع تعطيل Error If Not Found.
   2. **Delete Files** مع تفعيل **Confirm Before Deleting**، ثم **Stop This Shortcut**.
9. **End Menu**
10. **End If**

**الجزء (ج): تحميل القواعد**

11. **Get File from Folder** للمسار `KFUPM Sorter/filters.txt` في **Shortcuts** (مع تعطيل Error If Not Found) ← **Get Text from Input** ← **Set Variable** باسم `F`.
12. **Get File from Folder** للمسار `KFUPM Sorter/courses.txt` في **Shortcuts** (مع تعطيل Error If Not Found) ← **Get Text from Input** ← **Set Variable** باسم `C`.
13. **Text**: `F` ثم سطر جديد ثم `C`. (تأتي الفلاتر المخصصة أولًا فتكون لها الأولوية.)
14. **Split Text** حسب **New Lines** ← **Set Variable** باسم `Rules`.
15. **Text**: الصق النص الآتي، ثم **Get Dictionary from Input** ← **Set Variable** باسم `Types`.

</div>

```json
{"pdf":"Documents","docx":"Documents","doc":"Documents","pptx":"Documents","ppt":"Documents","xlsx":"Documents","xls":"Documents","csv":"Documents","txt":"Documents","md":"Documents","rtf":"Documents","pages":"Documents","key":"Documents","numbers":"Documents","png":"Images","jpg":"Images","jpeg":"Images","gif":"Images","webp":"Images","heic":"Images","svg":"Images","mp4":"Videos","mov":"Videos","mkv":"Videos","m4v":"Videos","webm":"Videos","mp3":"Audio","m4a":"Audio","wav":"Audio","aac":"Audio","zip":"Archives","rar":"Archives","7z":"Archives","epub":"eBooks"}
```

<div dir="rtl">

**الجزء (د): الترتيب**

16. **Get Contents of Folder** للمجلد `Downloads` (مع تعطيل Recursive).
17. **Repeat with Each**:
    1. **Set Variable** باسم `File` وقيمته `Repeat Item`.
    2. **Get Details of Files**: **File Extension** للمتغير `File` ← **Change Case** إلى **lowercase** ← **Set Variable** باسم `Ext`.
    3. **If** `Ext` **has any value** (المجلدات بلا امتداد، فتُتجاوز):
       1. **Get Details of Files**: **Name** للمتغير `File` ← **Set Variable** باسم `FileName`.
       2. **Text** (فارغ) ← **Set Variable** باسم `Dest`.
       3. **Repeat with Each** لكل عنصر في `Rules`:
          1. **If** `Repeat Item 2` **contains** `|`:
             1. **If** `Dest` **does not have any value**:
                1. **Split Text** للعنصر `Repeat Item 2` حسب **Custom** بالقيمة `|` ← **Set Variable** باسم `Parts`.
                2. **Get Item from List**: **Last Item** من `Parts`.
                3. **Match Text**: النمط = `Item from List`، والنص = `FileName`، مع تعطيل **Case Sensitive**.
                4. **If** `Matches` **has any value**: **Get Item from List** **First Item** من `Parts` ← **Set Variable** باسم `Dest`، ثم **End If**.
             2. **End If**
          2. **End If**
       4. **End Repeat**
       5. **If** `Dest` **does not have any value**: **Get Dictionary Value** للمفتاح `Ext` من `Types` ← **Set Variable** باسم `Dest`، ثم **End If**.
       6. **If** `Dest` **has any value**:
          1. **Get File from Folder**: المسار `Dest` في `Downloads`، مع تعطيل **Error If Not Found**.
          2. **If** كانت النتيجة **does not have any value**: **Create Folder** بالمسار `Dest` في `Downloads`، ثم **End If**.
          3. **Get File from Folder**: المسار `Dest` في `Downloads` ← **Set Variable** باسم `Target`.
          4. **Move File** للمتغير `File` إلى `Target`، مع إبقاء **Replace** معطّلًا حتى لا يُستبدل أي ملف موجود.
       7. **End If**
    4. **End If**
18. **End Repeat**

شغّله مرة واحدة من تطبيق الاختصارات، واسمح له بالوصول إلى الملفات عندما يطلب ذلك.

---

## التشغيل التلقائي

لا يستطيع iOS مراقبة مجلد، لكنه يستطيع تشغيل الاختصار كلما أغلقت Safari (حيث تنزّل ملفات المقررات):

1. تطبيق الاختصارات ← **Automation** (الأتمتة) ← **+** ← **App** (تطبيق).
2. اختر **Safari**، وحدد **Is Closed**، وألغِ **Is Opened**، واختر **Run Immediately**.
3. **New Blank Automation** ← أضف **Text** بكلمة `auto` ← أضف **Run Shortcut** ← **KFUPM Sorter**، واجعل مُدخله هو النص السابق.

ويمكنك إضافة أتمتة ثانية بطريقة **Time of Day** (مثلًا كل يوم الساعة 11 مساءً) بالخطوات نفسها.

وعلى **Mac** افتح الاختصار مرة واحدة وأعد اختيار مجلد التنزيلات في الإجراء الأول (لأن اختيار المجلدات لا يُزامَن بين الأجهزة)، ثم شغّله من شريط القوائم أو من Dock.

---

<sub>مشروع طلابي مستقل، غير تابع لجامعة الملك فهد للبترول والمعادن ولا معتمد منها.</sub>

</div>
