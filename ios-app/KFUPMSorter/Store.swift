import Foundation
import SwiftUI

// Everything the app remembers lives on the device, in the app's own storage.
// These helpers are also used by the Shortcuts action, which runs without the window.

struct Course: Codable, Identifiable, Hashable {
    let code: String
    let title: String
    let credits: Int
    let subject: String
    var id: String { code }
}

private struct CatalogFile: Codable {
    let updated: String?
    let courses: [Course]
}

private struct SubjectEntry: Codable {
    let code: String
    let name: String
}

enum Catalog {
    /// The bundled KFUPM course catalog (same data as the Windows app).
    static let courses: [Course] = {
        guard let url = Bundle.main.url(forResource: "courses", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(CatalogFile.self, from: data) else { return [] }
        return file.courses
    }()

    static let updated: String = {
        guard let url = Bundle.main.url(forResource: "courses", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(CatalogFile.self, from: data) else { return "" }
        return file.updated ?? ""
    }()

    static let subjectNames: [String: String] = {
        guard let url = Bundle.main.url(forResource: "subjects", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([SubjectEntry].self, from: data) else { return [:] }
        var out: [String: String] = [:]
        for s in list { out[s.code] = s.name }
        return out
    }()

    static let subjects: [String] = Array(Set(courses.map { $0.subject })).sorted()

    static func course(_ code: String) -> Course? { courses.first { $0.code == code } }
}

enum SettingsStore {
    private static let key = "settings.v1"

    static func load() -> SorterSettings {
        guard let data = UserDefaults.standard.data(forKey: key),
              let s = try? JSONDecoder().decode(SorterSettings.self, from: data) else { return SorterSettings() }
        return s
    }

    static func save(_ s: SorterSettings) {
        if let data = try? JSONEncoder().encode(s) { UserDefaults.standard.set(data, forKey: key) }
    }
}

/// Remembers the folder the user picked (normally iCloud Drive > Downloads) across launches.
enum FolderAccess {
    private static let key = "folder.bookmark"

    static func save(_ url: URL) throws {
        let ok = url.startAccessingSecurityScopedResource()
        defer { if ok { url.stopAccessingSecurityScopedResource() } }
        let data = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        UserDefaults.standard.set(data, forKey: key)
    }

    static func resolve() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale) else { return nil }
        if stale { try? save(url) }
        return url
    }

    static var folderName: String? { resolve()?.lastPathComponent }

    static func withAccess<T>(_ body: (URL) throws -> T) throws -> T {
        guard let url = resolve() else { throw SortError.noFolder }
        let ok = url.startAccessingSecurityScopedResource()
        defer { if ok { url.stopAccessingSecurityScopedResource() } }
        return try body(url)
    }
}

enum MoveLog {
    private static let key = "log.v1"
    private static let limit = 200

    static func load() -> [SortMove] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let list = try? JSONDecoder().decode([SortMove].self, from: data) else { return [] }
        return list
    }

    static func append(_ moves: [SortMove]) {
        guard !moves.isEmpty else { return }
        var list = moves + load()
        if list.count > limit { list = Array(list.prefix(limit)) }
        if let data = try? JSONEncoder().encode(list) { UserDefaults.standard.set(data, forKey: key) }
        UserDefaults.standard.set(Date(), forKey: "log.lastRun")
    }

    static func markRun() { UserDefaults.standard.set(Date(), forKey: "log.lastRun") }
    static var lastRun: Date? { UserDefaults.standard.object(forKey: "log.lastRun") as? Date }
}

/// One sort, used by the "Sort now" button and by the Shortcuts action.
enum Sorter {
    static func sortNow(dryRun: Bool = false) throws -> SortResult {
        let settings = SettingsStore.load()
        let result = try FolderAccess.withAccess { folder in
            try SortEngine.run(folder: folder, settings: settings, dryRun: dryRun)
        }
        if !dryRun {
            MoveLog.append(result.moves)
            MoveLog.markRun()
        }
        return result
    }
}

/// The window's state. Settings are saved as soon as they change.
@MainActor
final class AppModel: ObservableObject {
    @Published var settings: SorterSettings {
        didSet { if settings != oldValue { SettingsStore.save(settings) } }
    }
    @Published var folderName: String?
    @Published var log: [SortMove]
    @Published var lastMessage: String = ""

    init() {
        settings = SettingsStore.load()
        folderName = FolderAccess.folderName
        log = MoveLog.load()
    }

    var selectedCourses: [Course] {
        settings.courses.map { code in
            Catalog.course(code) ?? Course(code: code, title: "", credits: 0, subject: String(code.split(separator: " ").first ?? ""))
        }
    }

    var creditHours: Int { selectedCourses.reduce(0) { $0 + $1.credits } }

    func isSelected(_ c: Course) -> Bool { settings.courses.contains(c.code) }

    func toggle(_ c: Course) {
        if let i = settings.courses.firstIndex(of: c.code) { settings.courses.remove(at: i) }
        else { settings.courses.append(c.code) }
    }

    func pickFolder(_ url: URL) {
        do {
            try FolderAccess.save(url)
            folderName = FolderAccess.folderName
        } catch {
            lastMessage = error.localizedDescription
        }
    }

    /// Adds a filter, or replaces the one with the same folder name.
    func saveFilter(folder: String, keywordText: String, wholeWord: Bool) -> Bool {
        let name = folder.trimmingCharacters(in: .whitespacesAndNewlines)
        let bad = CharacterSet(charactersIn: "/\\:*?\"<>|")
        let keywords = SortEngine.splitKeywords(keywordText)
        guard !name.isEmpty, name.rangeOfCharacter(from: bad) == nil, !keywords.isEmpty else { return false }
        let filter = CustomFilter(folder: name, keywords: keywords, wholeWord: wholeWord)
        if let i = settings.customFilters.firstIndex(where: { $0.folder.lowercased() == name.lowercased() }) {
            settings.customFilters[i] = filter
        } else {
            settings.customFilters.append(filter)
        }
        return true
    }

    func sort(dryRun: Bool, lang: String) {
        do {
            let r = try Sorter.sortNow(dryRun: dryRun)
            log = MoveLog.load()
            if dryRun {
                lastMessage = r.moves.isEmpty ? L10n.s("preview.none", lang)
                    : L10n.s("preview.head", lang) + "\n" + r.moves.map { "\($0.file)  →  \($0.folder)" }.joined(separator: "\n")
            } else {
                lastMessage = L10n.fmt(L10n.s("sorted.fmt", lang), r.moves.count)
                if !r.errors.isEmpty { lastMessage += "\n" + r.errors.joined(separator: "\n") }
            }
        } catch {
            lastMessage = error.localizedDescription
        }
    }
}
