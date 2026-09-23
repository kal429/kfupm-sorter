# KFUPM Sorter for iPhone, iPad and Mac

[العربية](ios-shortcut.ar.md)

On Apple devices, KFUPM Sorter is a **Shortcut** in Apple's Shortcuts app. It does the same job as the Windows app: files in your **Downloads** folder go to a folder named after the course (`COE 301`, `EE 236`, ...) or a custom filter (`Internship`, ...). Anything else is sorted by type (`Documents`, `Images`, `Videos`, ...).

It never deletes anything and never sends anything anywhere. The only network call is when you pick your courses: it downloads the public course list from this repository.

---

## Option 1: install it with one tap (easiest)

1. On your iPhone or iPad, open the **Get the Shortcut** button on the [download page](https://kal429.github.io/kfupm-sorter-windows/). (If the button says *coming soon*, use Option 2 for now.)
2. Tap **Add Shortcut**.
3. Open the Shortcuts app and tap **KFUPM Sorter** once. It asks you to pick your **Downloads** folder (iCloud Drive → Downloads), then shows the menu.
4. Choose **Pick my courses** and select your courses (use the search bar, for example `coe 301`).
5. Set up automatic sorting as in [Make it automatic](#make-it-automatic).

Shortcuts sync through iCloud, so the same shortcut also appears on your iPad and Mac.

---

## Option 2: build it yourself (about 15 minutes)

Apple only lets people share shortcuts through iCloud links, so the shortcut above was built by hand in the Shortcuts app. These are the exact steps if you want to build or change your own copy.

> Action names below are the English names. If your iPhone is in Arabic, search for the same actions by their icons, or temporarily switch the iPhone language to English while building.

### Files it uses

The shortcut keeps two small text files in **iCloud Drive → Shortcuts → KFUPM Sorter**:

| File | One line per rule | Example |
|---|---|---|
| `courses.txt` | `FOLDER\|PATTERN` | `COE 301\|COE[\s_-]*301(?!\d)` |
| `filters.txt` | `FOLDER\|PATTERN` | `Internship\|(?<!\p{L})coop(?!\p{L})` |

You never edit these by hand; the menu writes them. The pattern for `COE 301` also matches `COE301`, `coe_301` and `COE-301`, but not `COE 3011`. A custom keyword matches as a whole word, so `lab` matches `Lab 3 Report.pdf` but not `Syllabus.pdf`.

### Build steps

Create a new shortcut named **KFUPM Sorter**. In its details (the **ⓘ** button), set **Receive** to **Text** (input from **Nowhere** is fine), so the automation can pass it the word `auto`.

Add these actions in order. Indented actions go inside the block above them.

**Part A: the Downloads folder**

1. **File**: tap the file field and choose the **Downloads** folder (iCloud Drive → Downloads, where Safari saves files).
2. **Set Variable** `Downloads` to the File.

**Part B: the menu (only when you open it yourself)**

3. **If** `Shortcut Input` **does not have any value**
4. &nbsp;&nbsp;**Choose from Menu** with prompt `KFUPM Sorter` and four items: `Sort now`, `Pick my courses`, `Add a custom filter`, `Clear custom filters`.
5. &nbsp;&nbsp;Under **Sort now**: nothing (leave it empty).
6. &nbsp;&nbsp;Under **Pick my courses**:
   1. **Get Contents of URL**: `https://raw.githubusercontent.com/kal429/kfupm-sorter-windows/main/ios/courses.txt`
   2. **Split Text** by **New Lines**.
   3. **Choose from List**, prompt `Pick your courses`, **Select Multiple** on.
   4. **Repeat with Each** item in Chosen Item:
      1. **Split Text** `Repeat Item` by **Custom** ` - ` (space, dash, space).
      2. **Get Item from List**: **First Item**.
      3. **Set Variable** `Code`.
      4. **Replace Text**: find ` ` (one space), replace with `[\s_-]*`, in `Code`. Leave **Regular Expression** off.
      5. **Text**: `Code` `|` `Updated Text` `(?!\d)` (no spaces between them).
      6. **Add to Variable** `CourseLines`.
   5. **End Repeat**
   6. **Combine Text** `CourseLines` with **New Lines**.
   7. **Save File**: turn **Ask Where to Save** off, destination **Shortcuts**, subpath `KFUPM Sorter/courses.txt`, **Overwrite If File Exists** on.
   8. **Show Notification**: `Courses saved`.
   9. **Stop This Shortcut**.
7. &nbsp;&nbsp;Under **Add a custom filter**:
   1. **Ask for Input** (Text), prompt `Folder name, for example Internship`. **Set Variable** `FilterFolder`.
   2. **Ask for Input** (Text), prompt `Keywords, separated by commas`.
   3. **Split Text** by **Custom** `,`.
   4. **Repeat with Each** item:
      1. **Replace Text**: find `^\s+|\s+$`, replace with nothing, in `Repeat Item`, **Regular Expression** on.
      2. **If** `Updated Text` **has any value**:
         1. **Text**: `FilterFolder` `|(?<!\p{L})` `Updated Text` `(?!\p{L})`
         2. **Add to Variable** `FilterLines`.
      3. **End If**
   5. **End Repeat**
   6. **Get File from Folder**: `KFUPM Sorter/filters.txt` in **Shortcuts**, **Error If Not Found** off.
   7. **Get Text from Input** (the file). **Set Variable** `OldFilters`.
   8. **Combine Text** `FilterLines` with **New Lines**.
   9. **Text**: `OldFilters`, then a new line, then `Combined Text`.
   10. **Save File**: Ask Where to Save off, **Shortcuts**, `KFUPM Sorter/filters.txt`, Overwrite on.
   11. **Show Notification**: `Filter saved`. **Stop This Shortcut**.
8. &nbsp;&nbsp;Under **Clear custom filters**:
   1. **Get File from Folder**: `KFUPM Sorter/filters.txt` in **Shortcuts**, Error If Not Found off.
   2. **Delete Files**, **Confirm Before Deleting** on. **Stop This Shortcut**.
9. &nbsp;&nbsp;**End Menu**
10. **End If**

**Part C: load the rules**

11. **Get File from Folder** `KFUPM Sorter/filters.txt` in **Shortcuts** (Error If Not Found off) → **Get Text from Input** → **Set Variable** `F`.
12. **Get File from Folder** `KFUPM Sorter/courses.txt` in **Shortcuts** (Error If Not Found off) → **Get Text from Input** → **Set Variable** `C`.
13. **Text**: `F`, new line, `C`. (Custom filters come first, so they win.)
14. **Split Text** by **New Lines** → **Set Variable** `Rules`.
15. **Text**: paste the block below, then **Get Dictionary from Input** → **Set Variable** `Types`.

```json
{"pdf":"Documents","docx":"Documents","doc":"Documents","pptx":"Documents","ppt":"Documents","xlsx":"Documents","xls":"Documents","csv":"Documents","txt":"Documents","md":"Documents","rtf":"Documents","pages":"Documents","key":"Documents","numbers":"Documents","png":"Images","jpg":"Images","jpeg":"Images","gif":"Images","webp":"Images","heic":"Images","svg":"Images","mp4":"Videos","mov":"Videos","mkv":"Videos","m4v":"Videos","webm":"Videos","mp3":"Audio","m4a":"Audio","wav":"Audio","aac":"Audio","zip":"Archives","rar":"Archives","7z":"Archives","epub":"eBooks"}
```

**Part D: sort**

16. **Get Contents of Folder** `Downloads` (Recursive off).
17. **Repeat with Each** item:
    1. **Set Variable** `File` to `Repeat Item`.
    2. **Get Details of Files**: **File Extension** of `File` → **Change Case** to **lowercase** → **Set Variable** `Ext`.
    3. **If** `Ext` **has any value** (folders have no extension, so they are skipped):
       1. **Get Details of Files**: **Name** of `File` → **Set Variable** `FileName`.
       2. **Text** (leave empty) → **Set Variable** `Dest`.
       3. **Repeat with Each** item in `Rules`:
          1. **If** `Repeat Item 2` **contains** `|`:
             1. **If** `Dest` **does not have any value**:
                1. **Split Text** `Repeat Item 2` by **Custom** `|` → **Set Variable** `Parts`.
                2. **Get Item from List**: **Last Item** of `Parts`.
                3. **Match Text**: pattern = `Item from List`, text = `FileName`, **Case Sensitive** off.
                4. **If** `Matches` **has any value**: **Get Item from List** **First Item** of `Parts` → **Set Variable** `Dest`. **End If**
             2. **End If**
          2. **End If**
       4. **End Repeat**
       5. **If** `Dest` **does not have any value**: **Get Dictionary Value** for key `Ext` in `Types` → **Set Variable** `Dest`. **End If**
       6. **If** `Dest` **has any value**:
          1. **Get File from Folder**: path `Dest` in `Downloads`, **Error If Not Found** off.
          2. **If** `File` (the result) **does not have any value**: **Create Folder** at path `Dest` in `Downloads`. **End If**
          3. **Get File from Folder**: path `Dest` in `Downloads` → **Set Variable** `Target`.
          4. **Move File** `File` to `Target`. Leave **Replace** off, so an existing file is never overwritten.
       7. **End If**
    4. **End If**
18. **End Repeat**

Run it once from the Shortcuts app and allow the file access it asks for.

---

## Make it automatic

iOS cannot watch a folder, but it can run the shortcut every time you close Safari (where you download course files):

1. Shortcuts app → **Automation** → **+** → **App**.
2. Choose **Safari**, tick **Is Closed**, untick **Is Opened**, choose **Run Immediately**.
3. **New Blank Automation** → add **Text** with the word `auto` → add **Run Shortcut** → **KFUPM Sorter**, and set its input to the Text.

You can add a second automation with **Time of Day** (for example every day at 11 PM) the same way.

On a **Mac**, open the shortcut once and re-pick your Downloads folder in the first action (folder choices do not sync between devices). You can then run it from the menu bar or the Dock.

---

<sub>An independent student project. Not affiliated with or endorsed by King Fahd University of Petroleum and Minerals.</sub>
