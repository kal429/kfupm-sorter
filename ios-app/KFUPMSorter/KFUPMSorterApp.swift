import SwiftUI
import UniformTypeIdentifiers

extension Color {
    // KFUPM brand colors (style board): green, forest, petrol, gold
    static let kGreen  = Color(red: 0 / 255, green: 133 / 255, blue: 64 / 255)
    static let kForest = Color(red: 0 / 255, green: 87 / 255, blue: 63 / 255)
    static let kPetrol = Color(red: 0 / 255, green: 62 / 255, blue: 81 / 255)
    static let kGold   = Color(red: 218 / 255, green: 201 / 255, blue: 97 / 255)
}

@main
struct KFUPMSorterApp: App {
    @StateObject private var model = AppModel()
    @AppStorage("lang") private var lang = "en"

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .environment(\.layoutDirection, lang == "ar" ? .rightToLeft : .leftToRight)
                .environment(\.locale, Locale(identifier: lang == "ar" ? "ar" : "en"))
                .tint(.kGreen)
        }
    }
}

struct RootView: View {
    @AppStorage("lang") private var lang = "en"
    private func t(_ k: String) -> String { L10n.s(k, lang) }

    var body: some View {
        TabView {
            CoursesView()
                .tabItem { Label(t("tab.courses"), systemImage: "books.vertical") }
            FiltersView()
                .tabItem { Label(t("tab.filters"), systemImage: "line.3.horizontal.decrease.circle") }
            SortView()
                .tabItem { Label(t("tab.sort"), systemImage: "folder.badge.gearshape") }
            AboutView()
                .tabItem { Label(t("tab.about"), systemImage: "info.circle") }
        }
    }
}

/// Green KFUPM navigation bar with white title.
struct KFUPMBar: ViewModifier {
    let title: String
    func body(content: Content) -> some View {
        content
            .navigationTitle(title)
            .toolbarBackground(Color.kGreen, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

extension View {
    func kfupmBar(_ title: String) -> some View { modifier(KFUPMBar(title: title)) }
}

// MARK: - Courses

struct CoursesView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage("lang") private var lang = "en"
    @State private var search = ""
    @State private var dept = ""
    private func t(_ k: String) -> String { L10n.s(k, lang) }

    private var shown: [Course] {
        var list = Catalog.courses
        if !dept.isEmpty { list = list.filter { $0.subject == dept } }
        let q = search.trimmingCharacters(in: .whitespaces)
        if !q.isEmpty {
            let compact = q.replacingOccurrences(of: " ", with: "").lowercased()
            list = list.filter {
                $0.code.replacingOccurrences(of: " ", with: "").lowercased().contains(compact)
                    || $0.title.localizedCaseInsensitiveContains(q)
            }
        }
        return list
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text(t("lbl.term"))
                        TextField(t("term.placeholder"), text: $model.settings.term)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    Toggle(isOn: $model.settings.termFolder) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(t("chk.termFolder"))
                            Text(t("term.example")).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    if model.selectedCourses.isEmpty {
                        Text(t("mine.none")).foregroundStyle(.secondary)
                    }
                    ForEach(model.selectedCourses) { c in
                        CourseRow(course: c, selected: true)
                    }
                    .onDelete { idx in model.settings.courses.remove(atOffsets: idx) }
                } header: {
                    Text(t("lbl.mine"))
                } footer: {
                    if !model.selectedCourses.isEmpty {
                        Text(L10n.fmt(t("credits.fmt"), model.selectedCourses.count, model.creditHours))
                            .foregroundStyle(Color.kForest)
                    }
                }

                Section {
                    Picker(t("lbl.dept"), selection: $dept) {
                        Text(t("dept.all")).tag("")
                        ForEach(Catalog.subjects, id: \.self) { s in
                            Text(s + "  " + (Catalog.subjectNames[s] ?? "")).tag(s)
                        }
                    }
                    ForEach(shown.prefix(400)) { c in
                        Button { model.toggle(c) } label: {
                            CourseRow(course: c, selected: model.isSelected(c))
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text(t("lbl.catalog"))
                } footer: {
                    Text(L10n.fmt(t("fmt.shown"), min(shown.count, 400)))
                }
            }
            .searchable(text: $search, prompt: t("search.prompt"))
            .kfupmBar("KFUPM Sorter")
        }
    }
}

struct CourseRow: View {
    let course: Course
    let selected: Bool
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(selected ? Color.kGreen : Color.secondary)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(course.code).font(.headline)
                if !course.title.isEmpty {
                    Text(course.title).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .environment(\.layoutDirection, .leftToRight)
            Spacer()
            if course.credits > 0 {
                Text("\(course.credits) cr").font(.caption).foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Custom filters

struct FiltersView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage("lang") private var lang = "en"
    @State private var folder = ""
    @State private var keywords = ""
    @State private var wholeWord = true
    @State private var showBad = false
    private func t(_ k: String) -> String { L10n.s(k, lang) }

    private var editing: Bool {
        model.settings.customFilters.contains { $0.folder.lowercased() == folder.trimmingCharacters(in: .whitespaces).lowercased() }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(t("cust.help")).font(.subheadline)
                    Text(t("cust.example")).font(.caption).foregroundStyle(.secondary)
                } header: { Text(t("cust.head")) }

                Section {
                    TextField(t("cust.folder"), text: $folder)
                        .textInputAutocapitalization(.words)
                    TextField(t("cust.keywords"), text: $keywords)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Toggle(isOn: $wholeWord) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(t("cust.whole"))
                            Text(t("cust.wholeHint")).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Button {
                        if model.saveFilter(folder: folder, keywordText: keywords, wholeWord: wholeWord) {
                            folder = ""; keywords = ""; wholeWord = true
                        } else {
                            showBad = true
                        }
                    } label: {
                        Label(editing ? t("cust.update") : t("cust.add"), systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }

                Section {
                    if model.settings.customFilters.isEmpty {
                        Text(t("cust.empty")).foregroundStyle(.secondary)
                    }
                    ForEach(model.settings.customFilters) { f in
                        Button {
                            folder = f.folder
                            keywords = f.keywords.joined(separator: ", ")
                            wholeWord = f.wholeWord
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(f.folder).font(.headline)
                                Text(f.keywords.joined(separator: ", ") + "  ·  " + (f.wholeWord ? t("cust.wordTag") : t("cust.anyTag")))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { idx in model.settings.customFilters.remove(atOffsets: idx) }
                } header: { Text(t("cust.list")) }
            }
            .alert(t("cust.bad"), isPresented: $showBad) { Button("OK", role: .cancel) {} }
            .kfupmBar(t("tab.filters"))
        }
    }
}

// MARK: - Sorting

struct SortView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage("lang") private var lang = "en"
    @Environment(\.openURL) private var openURL
    @State private var picking = false
    @State private var showMessage = false
    private func t(_ k: String) -> String { L10n.s(k, lang) }

    private func typeBinding(_ name: String) -> Binding<Bool> {
        Binding(
            get: { model.settings.typeGroups.contains(name) },
            set: { on in
                if on { if !model.settings.typeGroups.contains(name) { model.settings.typeGroups.append(name) } }
                else { model.settings.typeGroups.removeAll { $0 == name } }
            }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Image(systemName: "folder.fill").foregroundStyle(Color.kGreen)
                        Text(model.folderName ?? t("folder.none"))
                            .foregroundStyle(model.folderName == nil ? Color.secondary : Color.primary)
                    }
                    Button(model.folderName == nil ? t("folder.pick") : t("folder.change")) { picking = true }
                } header: { Text(t("lbl.folder")) } footer: { Text(t("folder.hint")) }

                Section {
                    Button {
                        model.sort(dryRun: false, lang: lang)
                        showMessage = true
                    } label: {
                        Label(t("btn.sortNow"), systemImage: "arrow.down.doc.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.folderName == nil)
                    Button(t("btn.preview")) {
                        model.sort(dryRun: true, lang: lang)
                        showMessage = true
                    }
                    .disabled(model.folderName == nil)
                } header: { Text(t("lbl.run")) } footer: {
                    if let d = MoveLog.lastRun {
                        Text(L10n.fmt(t("last.fmt"), d.formatted(date: .abbreviated, time: .shortened)))
                    }
                }

                Section {
                    Text(t("auto.help")).font(.subheadline)
                    Button(t("auto.open")) {
                        if let u = URL(string: "shortcuts://") { openURL(u) }
                    }
                } header: { Text(t("lbl.auto")) }

                Section {
                    Toggle(t("chk.byType"), isOn: $model.settings.sortByType)
                    if model.settings.sortByType {
                        ForEach(TypeGroup.all) { g in
                            Toggle(isOn: typeBinding(g.name)) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(t("type." + g.name))
                                    Text(g.name + "/  ·  " + g.exts.prefix(4).map { "." + $0 }.joined(separator: " "))
                                        .font(.caption).foregroundStyle(.secondary)
                                        .environment(\.layoutDirection, .leftToRight)
                                }
                            }
                        }
                        Toggle(t("chk.other"), isOn: $model.settings.otherFolder)
                    }
                } header: { Text(t("lbl.unmatched")) }

                Section {
                    if model.log.isEmpty {
                        Text(t("log.empty")).foregroundStyle(.secondary)
                    }
                    ForEach(model.log.prefix(50)) { m in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(m.file).font(.subheadline).lineLimit(1)
                            Text("→ " + m.folder + "   " + m.date.formatted(date: .omitted, time: .shortened))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .environment(\.layoutDirection, .leftToRight)
                    }
                } header: { Text(t("lbl.recent")) }

                Section {
                    ForEach(1...4, id: \.self) { i in
                        Label(t("safe.\(i)"), systemImage: "checkmark.shield").font(.subheadline)
                    }
                } header: { Text(t("lbl.safety")) }
            }
            .fileImporter(isPresented: $picking, allowedContentTypes: [.folder]) { result in
                if case .success(let url) = result { model.pickFolder(url) }
            }
            .alert("KFUPM Sorter", isPresented: $showMessage) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(model.lastMessage)
            }
            .onAppear { model.log = MoveLog.load() }
            .kfupmBar(t("tab.sort"))
        }
    }
}

// MARK: - About

struct AboutView: View {
    @AppStorage("lang") private var lang = "en"
    private func t(_ k: String) -> String { L10n.s(k, lang) }
    private var version: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.1.0"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(t("lbl.lang"), selection: $lang) {
                        Text("English").tag("en")
                        Text("العربية").tag("ar")
                    }
                    .pickerStyle(.segmented)
                } header: { Text(t("lbl.lang")) }

                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("KFUPM Sorter").font(.title2.bold()).foregroundStyle(Color.kGreen)
                        Text(t("app.subtitle")).foregroundStyle(.secondary)
                        Text(L10n.fmt(t("about.version"), version)).font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    Text(L10n.fmt(t("catalog.fmt"), Catalog.courses.count, Catalog.subjects.count, Catalog.updated))
                    Text(t("about.source")).font(.caption).foregroundStyle(.secondary)
                } header: { Text(t("about.catalog")) }

                Section {
                    Text(t("privacy.1"))
                } header: { Text(t("about.privacy")) }

                Section {
                    Link("github.com/kal429/kfupm-sorter", destination: URL(string: "https://github.com/kal429/kfupm-sorter")!)
                } header: { Text(t("about.open")) } footer: {
                    Text(t("about.disclaimer"))
                }
            }
            .kfupmBar(t("tab.about"))
        }
    }
}
