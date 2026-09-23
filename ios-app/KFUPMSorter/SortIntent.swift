import AppIntents
import Foundation

/// The "Sort Downloads" action for the Shortcuts app. It runs in the background,
/// without opening the app, so an automation such as "When Safari is closed"
/// can keep the Downloads folder sorted.
struct SortDownloadsIntent: AppIntent {
    static var title: LocalizedStringResource = "Sort Downloads"
    static var description = IntentDescription("Moves new files in your Downloads folder into their course, filter and file-type folders.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let result = try Sorter.sortNow(dryRun: false)
        let message = L10n.fmt(L10n.s("intent.done", L10n.current), result.moves.count)
        return .result(dialog: "\(message)")
    }
}

struct KFUPMSorterShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SortDownloadsIntent(),
            phrases: ["Sort downloads with \(.applicationName)", "Sort my downloads in \(.applicationName)"],
            shortTitle: "Sort Downloads",
            systemImageName: "folder.badge.gearshape"
        )
    }
}
