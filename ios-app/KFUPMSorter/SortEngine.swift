import Foundation

// The sorting rules, identical to the Windows engine (src/KfupmSorter.ps1):
// custom filters first, then courses, then file types, then the optional "Other" folder.
// Nothing is ever deleted or overwritten; a duplicate name becomes "name (1).ext".

struct TypeGroup: Identifiable {
    let name: String
    let exts: [String]
    let defaultOn: Bool
    var id: String { name }

    static let all: [TypeGroup] = [
        TypeGroup(name: "Documents",   exts: ["pdf", "docx", "doc", "pptx", "ppt", "xlsx", "xls", "csv", "txt", "md", "rtf", "odt", "pages", "key", "numbers"], defaultOn: true),
        TypeGroup(name: "Images",      exts: ["png", "jpg", "jpeg", "gif", "webp", "bmp", "heic", "svg", "tiff"], defaultOn: true),
        TypeGroup(name: "Videos",      exts: ["mp4", "mkv", "avi", "mov", "webm", "wmv", "flv", "m4v"], defaultOn: true),
        TypeGroup(name: "Audio",       exts: ["mp3", "wav", "flac", "m4a", "aac", "ogg", "wma"], defaultOn: true),
        TypeGroup(name: "Installers",  exts: ["exe", "msi", "msix", "appx", "iso", "cab", "apk", "dmg", "pkg", "ipa"], defaultOn: true),
        TypeGroup(name: "Archives",    exts: ["zip", "rar", "7z", "tar", "gz", "bz2"], defaultOn: true),
        TypeGroup(name: "Code",        exts: ["py", "js", "ts", "java", "c", "cpp", "h", "cs", "json", "xml", "html", "css", "jar", "ipynb", "m", "r", "asm", "swift"], defaultOn: false),
        TypeGroup(name: "3D Printing", exts: ["stl", "3mf", "obj", "gcode", "step", "stp", "f3d"], defaultOn: false),
        TypeGroup(name: "eBooks",      exts: ["epub", "mobi", "azw3", "djvu"], defaultOn: false),
    ]
}

struct CustomFilter: Codable, Identifiable, Equatable {
    var id = UUID()
    var folder: String
    var keywords: [String]
    var wholeWord: Bool
}

struct SorterSettings: Codable, Equatable {
    var term: String = ""
    var termFolder: Bool = false
    var courses: [String] = []                 // course codes, e.g. "COE 301"
    var customFilters: [CustomFilter] = []
    var sortByType: Bool = true
    var typeGroups: [String] = TypeGroup.all.filter { $0.defaultOn }.map { $0.name }
    var otherFolder: Bool = false
}

struct SortMove: Codable, Identifiable {
    var id = UUID()
    let date: Date
    let file: String
    let folder: String
}

struct SortResult {
    var moves: [SortMove] = []
    var errors: [String] = []
}

enum SortError: LocalizedError {
    case noFolder
    case folderUnreadable(String)

    var errorDescription: String? {
        switch self {
        case .noFolder: return L10n.s("err.noFolder", L10n.current)
        case .folderUnreadable(let why): return L10n.s("err.folder", L10n.current) + " " + why
        }
    }
}

enum SortEngine {
    static let skipExtensions: Set<String> = ["crdownload", "part", "partial", "tmp", "download", "opdownload", "!ut", "lock", "icloud"]
    static let ignoreNames: Set<String> = ["desktop.ini", ".ds_store"]
    static let minAgeSeconds: TimeInterval = 20

    /// "COE 301" -> COE[\s_-]*301(?!\d)  (matches COE301, coe_301, COE-301, but not COE 3011)
    static func coursePattern(_ code: String) -> String {
        let parts = code.split(separator: " ")
        if parts.count == 2, parts[0].allSatisfy({ $0.isLetter }), parts[1].allSatisfy({ $0.isNumber }) {
            return "\(parts[0])[\\s_-]*\(parts[1])(?!\\d)"
        }
        return NSRegularExpression.escapedPattern(for: code)
    }

    /// A keyword; with wholeWord, "lab" matches "Lab 3 Report.pdf" but not "Syllabus.pdf".
    static func keywordPattern(_ keyword: String, wholeWord: Bool) -> String {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        var escaped = NSRegularExpression.escapedPattern(for: trimmed)
        escaped = escaped.replacingOccurrences(of: "\\ ", with: " ")
        escaped = escaped.replacingOccurrences(of: " ", with: "[\\s_-]*")
        return wholeWord ? "(?<!\\p{L})" + escaped + "(?!\\p{L})" : escaped
    }

    /// Splits "a, b، c" into clean keywords.
    static func splitKeywords(_ text: String) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for part in text.components(separatedBy: CharacterSet(charactersIn: ",،;")) {
            let k = part.trimmingCharacters(in: .whitespacesAndNewlines)
            if !k.isEmpty && !seen.contains(k.lowercased()) {
                seen.insert(k.lowercased())
                out.append(k)
            }
        }
        return out
    }

    struct Rule {
        let folder: String
        let regex: NSRegularExpression
    }

    static func rules(for s: SorterSettings) -> [Rule] {
        var out: [Rule] = []
        for f in s.customFilters {
            for k in f.keywords {
                if let re = try? NSRegularExpression(pattern: keywordPattern(k, wholeWord: f.wholeWord), options: [.caseInsensitive]) {
                    out.append(Rule(folder: f.folder, regex: re))
                }
            }
        }
        let term = s.term.trimmingCharacters(in: .whitespaces)
        for code in s.courses {
            let folder = (s.termFolder && !term.isEmpty) ? term + "/" + code : code
            if let re = try? NSRegularExpression(pattern: coursePattern(code), options: [.caseInsensitive]) {
                out.append(Rule(folder: folder, regex: re))
            }
        }
        return out
    }

    /// Folder (relative to the watched folder) a file belongs in, or nil to leave it alone.
    static func destination(fileName: String, rules: [Rule], settings s: SorterSettings) -> String? {
        let range = NSRange(fileName.startIndex..<fileName.endIndex, in: fileName)
        for r in rules where r.regex.firstMatch(in: fileName, options: [], range: range) != nil {
            return r.folder
        }
        guard s.sortByType else { return nil }
        let ext = (fileName as NSString).pathExtension.lowercased()
        if ext.isEmpty { return nil }
        for g in TypeGroup.all where s.typeGroups.contains(g.name) && g.exts.contains(ext) {
            return g.name
        }
        return s.otherFolder ? "Other" : nil
    }

    static func uniqueURL(in dir: URL, name: String) -> URL {
        let fm = FileManager.default
        var candidate = dir.appendingPathComponent(name)
        if !fm.fileExists(atPath: candidate.path) { return candidate }
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        var i = 1
        repeat {
            let n = ext.isEmpty ? "\(base) (\(i))" : "\(base) (\(i)).\(ext)"
            candidate = dir.appendingPathComponent(n)
            i += 1
        } while fm.fileExists(atPath: candidate.path)
        return candidate
    }

    /// Sorts the files directly inside `folder` (never its subfolders).
    static func run(folder: URL, settings: SorterSettings, dryRun: Bool, now: Date = Date()) throws -> SortResult {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.isDirectoryKey, .contentModificationDateKey, .creationDateKey]
        let items: [URL]
        do {
            items = try fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])
        } catch {
            throw SortError.folderUnreadable(error.localizedDescription)
        }
        let ruleList = rules(for: settings)
        var result = SortResult()

        for url in items.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let values = try? url.resourceValues(forKeys: Set(keys))
            if values?.isDirectory == true { continue }
            let name = url.lastPathComponent
            if name.hasPrefix(".") || ignoreNames.contains(name.lowercased()) { continue }
            if skipExtensions.contains(url.pathExtension.lowercased()) { continue }
            let changed = max(values?.contentModificationDate ?? .distantPast, values?.creationDate ?? .distantPast)
            if now.timeIntervalSince(changed) < minAgeSeconds { continue }   // still downloading

            guard let rel = destination(fileName: name, rules: ruleList, settings: settings) else { continue }
            if dryRun {
                result.moves.append(SortMove(date: now, file: name, folder: rel))
                continue
            }
            var destDir = folder
            for part in rel.split(separator: "/") { destDir.appendPathComponent(String(part), isDirectory: true) }
            do {
                try fm.createDirectory(at: destDir, withIntermediateDirectories: true)
                let target = uniqueURL(in: destDir, name: name)
                try coordinatedMove(url, to: target)
                result.moves.append(SortMove(date: now, file: name, folder: rel))
            } catch {
                result.errors.append(name + ": " + error.localizedDescription)
            }
        }
        return result
    }

    /// Moves through NSFileCoordinator so iCloud Drive and the Files app stay in sync.
    static func coordinatedMove(_ source: URL, to target: URL) throws {
        var coordinationError: NSError?
        var moveError: Error?
        NSFileCoordinator(filePresenter: nil).coordinate(
            writingItemAt: source, options: .forMoving,
            writingItemAt: target, options: .forReplacing,
            error: &coordinationError
        ) { from, to in
            do { try FileManager.default.moveItem(at: from, to: to) } catch { moveError = error }
        }
        if let e = coordinationError { throw e }
        if let e = moveError { throw e }
    }
}
