# KFUPM Sorter Desktop (Windows + macOS, Java)

[العربية](#بالعربية)

The same KFUPM Sorter as the Windows app, written in Java so one program runs on **Windows and macOS**. Java is bundled inside the installer, so nobody has to install Java.

- Pick your courses from the official KFUPM catalog (2,123 courses, 58 departments), add custom filters, sort everything else by file type.
- English and Arabic interface (right-to-left in Arabic).
- **Automatic sorting**: a small background sorter checks your Downloads folder every minute and starts when you sign in. It shows an icon in the system tray (Windows) or menu bar (Mac) with *Open*, *Sort now* and *Stop*.
- Never deletes, never overwrites, leaves unfinished downloads alone, and sends nothing anywhere.
- Reads and writes the same `rules.json` format as the Windows PowerShell edition. On first start it offers your PowerShell-edition choices automatically.

## Download

From the [latest release](https://github.com/kal429/kfupm-sorter/releases/latest):

| System | File |
|---|---|
| Mac with Apple silicon (M1 or newer) | `KFUPM-Sorter-Desktop-macOS-AppleSilicon.dmg` |
| Mac with Intel | `KFUPM-Sorter-Desktop-macOS-Intel.dmg` |
| Windows 10 / 11 | `KFUPM-Sorter-Desktop-Windows-Setup.exe` |

**Mac:** open the .dmg and drag *KFUPM Sorter Desktop* into Applications. The app is not notarized by Apple yet, so the first time right-click it and choose **Open** (on macOS 15: *System Settings › Privacy & Security › Open Anyway*). When macOS asks to let it use your Downloads folder, choose **Allow**.

**Windows:** use either this installer or the regular `KFUPM-Sorter-Setup.exe`, not both, so two sorters don't work on the same folder.

## How the code is organised

| File | What it does |
|---|---|
| `Main.java` | Starts the window, or the background sorter with `--background` |
| `Engine.java` | The sorting rules: custom filters, then courses, then file types. Safe moves only |
| `Settings.java` | Your choices, saved as `rules.json` (same format as the PowerShell edition) |
| `Catalog.java` | The bundled course list, and the update from bulletin.kfupm.edu.sa |
| `Background.java` | Sorts every minute; tray / menu-bar icon |
| `Autostart.java` | Starts the background sorter at sign-in (Startup folder / LaunchAgent), no admin rights |
| `Strings.java` | English and Arabic text |
| `ui/MainWindow.java`, `ui/Theme.java` | The window (Swing) and the KFUPM colors |
| `Json.java` | A tiny JSON reader and writer, so there are no libraries at all |
| `src/test/.../SelfTest.java` | 31 checks of the rules and the engine |

## Build it yourself

You only need a JDK, version 21 or newer ([Temurin](https://adoptium.net) is free).

```
cd desktop-app
./build.sh          # compile, run the self-test, make build/jar/kfupm-sorter-desktop.jar
./build.sh run      # ... and open the window
./build.sh package  # ... and make the Mac .dmg (on a Mac) with jpackage
```

On Windows, run it from Git Bash, or let GitHub build everything: every change to `desktop-app/` runs [`desktop.yml`](../.github/workflows/desktop.yml), and every release tag attaches the installers to the release.

---

<div dir="rtl">

## بالعربية

هذا هو KFUPM Sorter نفسه، لكنه مكتوب بلغة Java ليعمل البرنامج الواحد على **Windows وmacOS**. وJava مرفقة داخل ملف التثبيت، فلا يحتاج أحد إلى تثبيتها.

- اختر مقرراتك من الدليل الرسمي للجامعة، وأضف فلاترك المخصصة، ويُرتَّب ما سوى ذلك حسب نوع الملف.
- واجهة بالإنجليزية والعربية (من اليمين إلى اليسار بالعربية).
- **ترتيب تلقائي**: يفحص مجلد التنزيلات كل دقيقة ويبدأ عند تسجيل الدخول، مع أيقونة في شريط المهام (Windows) أو شريط القوائم (Mac).
- لا يحذف ولا يستبدل أي ملف، ولا يرسل أي بيانات.

**على Mac:** افتح ملف .dmg واسحب *KFUPM Sorter Desktop* إلى مجلد التطبيقات. ولأن التطبيق غير موثَّق من Apple بعد، افتحه أول مرة بالنقر بالزر الأيمن ثم **فتح** (وفي macOS 15: الإعدادات ‹ الخصوصية والأمان ‹ فتح على أي حال)، واسمح له باستخدام مجلد التنزيلات عندما يطلب ذلك.

**على Windows:** استعمل هذا المثبِّت أو المثبِّت العادي `KFUPM-Sorter-Setup.exe`، لا كليهما معًا.

</div>
