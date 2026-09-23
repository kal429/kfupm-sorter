<p align="center"><img src="docs/icon-256.png" width="110" alt="KFUPM Sorter icon"></p>

<h1 align="center">KFUPM Sorter</h1>

<p align="center">Keeps your Downloads folder sorted by course, automatically.<br>
Windows app &middot; iPhone, iPad &amp; Mac shortcut &middot; English and Arabic</p>

<p align="center">
  <a href="https://github.com/kal429/kfupm-sorter/releases/latest/download/KFUPM-Sorter-Setup.exe"><b>Download for Windows</b></a> &nbsp;&middot;&nbsp;
  <a href="docs/ios-shortcut.md"><b>iPhone, iPad &amp; Mac</b></a> &nbsp;&middot;&nbsp;
  <a href="https://kal429.github.io/kfupm-sorter/">Website</a> &nbsp;&middot;&nbsp;
  <a href="README.ar.md">العربية</a>
</p>

---

## What it does

You pick your courses for the term from the official KFUPM course list. From then on, every file you download goes to its course folder on its own, and anything that is not course material is sorted by type.

```
Downloads/
├── 261/
│   ├── COE 301/          <- Lecture_T261_COE_301_Ch3.pdf
│   ├── EE 236/           <- 261-EE236-L2-Resistive Circuits.pdf
│   └── ENGL 214/         <- ENGL214_Progress_Report.docx
├── Internship/           <- Internship_Offer_Letter.pdf          (custom filter)
├── Documents/            <- anything else that is a pdf, docx, pptx...
├── Videos/
├── Installers/
└── Archives/
```

- **2,123 courses from 58 departments**, taken from the official bulletin (bulletin.kfupm.edu.sa). One button refreshes the list every term.
- **Pick courses with checkboxes**, no typing. Filter by department or search by code or name.
- **Smart matching.** `COE 301` catches `COE301_Lab.pdf`, `Coe-301 HW.docx` and `261-COE301-L1.pdf`, but not `COE 3011`.
- **Runs silently every minute** in the background, starts with Windows, no window pops up.
- **Custom filters.** Add your own folder with a few keywords, for an internship, a club or a side project. `Internship` with the keywords `internship, coop` catches `Internship_Offer_Letter.pdf` and `COOP Report.docx`. Keywords match whole words, so `lab` catches `Lab 3 Report.pdf` but not `Syllabus.pdf`. Custom filters are checked before courses.
- **Optional term folders** (`261\COE 301`), so each semester stays separate.
- **English or Arabic interface**, switchable from the top of the window. English is the default.
- **KFUPM colors**, green and gold.

## Safety

- It **never deletes** anything. It only moves files.
- It **never overwrites**. A duplicate name becomes `name (1).pdf`.
- It waits for downloads to finish: `.crdownload` / `.part` files, files younger than 20 seconds and files open in another program are left alone.
- It only moves files, never folders, and leaves alone anything that matches no rule.
- Every move is logged with a timestamp, visible in the **Status** tab.
- It works fully offline on your PC and sends nothing anywhere. The only network access is the optional "update catalog" button, which reads the public bulletin pages.
- All the code is plain PowerShell in [`src/`](src). You can read every line before you install.

## Install

### Windows

1. Download **[KFUPM-Sorter-Setup.exe](https://github.com/kal429/kfupm-sorter/releases/latest/download/KFUPM-Sorter-Setup.exe)**. This link always points to the newest version.
2. Run it. No administrator rights needed. It installs for your user only.
3. Pick your courses, add any custom filters, press **Save**, and accept "turn on automatic sorting".

> **"Windows protected your PC"?** The installer is not code-signed yet (a signing certificate is paid), so SmartScreen shows this for any new app. Click **More info → Run anyway**. If you would rather check first, every file in the installer is in [`src/`](src).

To uninstall, use **Settings → Apps → KFUPM Sorter → Uninstall**. The background task is removed, and your sorted files stay where they are.

### iPhone, iPad and Mac

On Apple devices KFUPM Sorter is a shortcut in Apple's Shortcuts app, with the same course list, custom filters and sorting by type. It runs automatically whenever you close Safari. See the **[iPhone, iPad and Mac guide](docs/ios-shortcut.md)** ([العربية](docs/ios-shortcut.ar.md)).

There is also a native **iPhone / iPad app** (SwiftUI) in [`ios-app/`](ios-app), built automatically on GitHub into `KFUPM-Sorter-iOS.ipa`. It adds a *Sort Downloads* action to Shortcuts, so the same automation runs without opening the app. Installing it needs Sideloadly (free, from Windows) or an Apple Developer account; see [`ios-app/README.md`](ios-app/README.md).

## Build the installer yourself

Publishing a release on GitHub (for example `v1.1.0`) builds the installer on GitHub Actions and attaches `KFUPM-Sorter-Setup.exe` to that release automatically. See [`.github/workflows/build.yml`](.github/workflows/build.yml).

To build it on your own PC:

```
1. Install Inno Setup 6 (free):   winget install JRSoftware.InnoSetup
2. Double-click:                   installer\build-installer.bat
3. Output:                         installer\output\KFUPM-Sorter-Setup.exe
```

## Project layout

| Path | What it is |
|---|---|
| `src/KfupmSorter.ps1` | The sorting engine: matching rules, safe moves, scheduled task |
| `src/Picker.ps1` | The window: courses, custom filters, sorting options, status, about |
| `src/Strings.ps1` | Interface text in English and Arabic |
| `src/Catalog.ps1` | Reads the course list from the KFUPM bulletin |
| `src/data/courses.json` | Bundled catalog, 2,123 courses, so it works offline on day one |
| `src/run-hidden.vbs` | Silent launcher, so no console window flashes every minute |
| `installer/KFUPM-Sorter.iss` | Inno Setup script that builds the `.exe` installer |
| `ios/courses.txt` | Course list read by the iPhone / iPad / Mac shortcut |
| `ios-app/` | Native iPhone / iPad app (SwiftUI) and its build spec |
| `docs/` | Download website (GitHub Pages) and the Apple guide |

Settings live in `%APPDATA%\KFUPM Sorter\` (`rules.json`, `settings.json`, `sorter.log`, `lastrun.txt`).

## Requirements

Windows 10 or 11. Everything it needs ships with Windows. The Apple version needs an up-to-date iPhone, iPad or Mac with the built-in Shortcuts app.

---

<sub>An independent student project. It is not affiliated with or endorsed by King Fahd University of Petroleum and Minerals. Course data comes from the university's public bulletin.</sub>

<sub>MIT License</sub>
