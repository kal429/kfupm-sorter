# KFUPM Sorter for iPhone and iPad (app)

[العربية](#بالعربية)

A native SwiftUI version of KFUPM Sorter with the same catalog of 2,123 KFUPM courses, custom filters, sorting by file type, safety rules and English/Arabic interface.

- **Courses** tab: tick your courses (search by code or title, filter by department), optional term folder.
- **Filters** tab: your own folders with keywords, for example `Internship` with `internship, coop, training`.
- **Sorting** tab: choose **iCloud Drive › Downloads** once, then **Sort now** or **Preview**.
- **Automatic**: the app adds a **Sort Downloads** action to the Shortcuts app. Add a personal automation *When Safari is closed → Sort Downloads* and it runs in the background, without opening the app.

It never deletes or overwrites anything, and nothing leaves your device.

## Getting the app

Every push to `ios-app/` builds the app on GitHub's Macs ([`ios.yml`](../.github/workflows/ios.yml)) and produces an unsigned **KFUPM-Sorter-iOS.ipa** (under *Actions*, and attached to each release).

Apple only runs signed apps, so pick one:

1. **Free, from Windows:** install [Sideloadly](https://sideloadly.io), plug in your iPhone, drag in `KFUPM-Sorter-iOS.ipa`, sign in with your Apple ID. On the iPhone: *Settings › General › VPN & Device Management* → trust your Apple ID, and turn on *Developer Mode* when asked. A free Apple ID signature lasts 7 days; re-sign it with Sideloadly after that.
2. **For everyone, permanently:** an Apple Developer account ($99/year) lets the app go on TestFlight or the App Store.

Requires iOS / iPadOS 17 or later. It also runs on Apple-silicon Macs as an iPad app.

## Building it yourself (Mac with Xcode)

```
brew install xcodegen
cd ios-app && xcodegen generate
open KFUPMSorter.xcodeproj
```

---

<div dir="rtl">

## بالعربية

نسخة أصلية من KFUPM Sorter لأجهزة iPhone وiPad مكتوبة بـ SwiftUI، فيها دليل المقررات نفسه (2,123 مقررًا)، والفلاتر المخصصة، والترتيب حسب نوع الملف، وضمانات الأمان، وواجهة بالعربية والإنجليزية.

- تبويب **المقررات**: حدّد مقرراتك (ابحث بالرمز أو الاسم، أو صفِّ حسب القسم)، مع خيار مجلد الفصل الدراسي.
- تبويب **الفلاتر**: مجلداتك الخاصة مع كلماتها المفتاحية.
- تبويب **الفرز**: اختر **iCloud Drive ‹ Downloads** مرة واحدة، ثم **رتّب الآن** أو **معاينة**.
- **التشغيل التلقائي**: يضيف التطبيق إجراء **Sort Downloads** إلى تطبيق الاختصارات. أضف أتمتة شخصية «عند إغلاق Safari ← Sort Downloads» فيعمل في الخلفية دون فتح التطبيق.

لا يحذف أي ملف ولا يستبدله، ولا يغادر جهازك أي شيء.

### الحصول على التطبيق

يُبنى التطبيق تلقائيًا على أجهزة Mac التابعة لـ GitHub مع كل تحديث، وينتج ملف **KFUPM-Sorter-iOS.ipa** غير موقَّع (في صفحة Actions، ومرفقًا بكل إصدار).

ولا يشغّل iPhone إلا التطبيقات الموقَّعة، فاختر إحدى الطريقتين:

1. **مجانًا من Windows:** ثبّت [Sideloadly](https://sideloadly.io)، ووصّل جهازك، واسحب ملف `KFUPM-Sorter-iOS.ipa`، وسجّل الدخول بحساب Apple ID. ثم من الجهاز: الإعدادات ‹ عام ‹ VPN وإدارة الجهاز ← ثق بحسابك، وفعّل وضع المطوّر عند الطلب. يدوم توقيع الحساب المجاني 7 أيام، ثم تعيد توقيعه بـ Sideloadly.
2. **للجميع وبشكل دائم:** حساب Apple Developer (99 دولارًا سنويًا) يتيح نشره عبر TestFlight أو App Store.

يتطلب iOS / iPadOS 17 أو أحدث.

</div>
