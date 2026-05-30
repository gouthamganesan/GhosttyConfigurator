import SwiftUI
import UniformTypeIdentifiers

/// Theme browser — the killer feature. Grid of every available theme with a
/// live `TerminalPreview` of the focused one. Tapping a tile selects it;
/// "Apply" writes through `ConfigStore`. Reached via NavigationLink from
/// AppearancePane.
struct ThemeBrowserView: View {
    @Environment(ConfigStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// Which slot we're editing: a single theme, or one half of a light/dark
    /// pair. The "Apply" button writes through the appropriate setter.
    let mode: ThemeBrowserMode

    @State private var themes: [Theme] = []
    @State private var isLoading: Bool = true
    @State private var search: String = ""
    @State private var filter: ThemeFilter
    @State private var selectedName: String?
    @State private var importError: String?
    @State private var showImportError: Bool = false

    init(mode: ThemeBrowserMode) {
        self.mode = mode
        // Pre-narrow the filter to match what the user is picking: opening the
        // dark-pair slot shouldn't dump 200 light themes on them. Single-mode
        // (match-system off) keeps the unfiltered list per the user's spec.
        _filter = State(initialValue: ThemeFilter.initial(for: mode))
    }

    private var filtered: [Theme] {
        themes
            .filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }
            .filter { filter.matches($0) }
    }

    private var selectedTheme: Theme? {
        guard let name = selectedName else { return nil }
        return themes.first { $0.name == name }
    }

    private let columns = [GridItem(.adaptive(minimum: 220, maximum: 260), spacing: 12)]

    var body: some View {
        VStack(spacing: 0) {
            // FIXED — name caption + preview. Lives below the toolbar with
            // its own opaque material so content doesn't sit under the toolbar.
            if let theme = selectedTheme {
                previewHeader(theme: theme)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.windowBackgroundColor))
            }

            // FIXED — filter chips, just below the preview, above the scroll.
            filterBar
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(.bar)

            Divider()

            // SCROLLABLE — theme grid only.
            ScrollView {
                if isLoading {
                    loadingState
                } else if filtered.isEmpty {
                    emptyState
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(filtered) { theme in
                            ThemeTile(
                                theme: theme,
                                isSelected: selectedName == theme.name
                            ) {
                                selectedName = theme.name
                            }
                        }
                    }
                    .padding(20)
                }
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .searchable(text: $search, placement: .toolbar, prompt: "Search themes")
        .navigationTitle(mode.title)
        .toolbar {
            ToolbarItem(placement: .secondaryAction) {
                Button {
                    importTheme()
                } label: {
                    Label("Import…", systemImage: "square.and.arrow.down")
                }
                .help("Import a theme from iTerm2 (.itermcolors)")
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Apply") {
                    if let theme = selectedTheme {
                        apply(theme)
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedName == nil)
            }
        }
        .alert("Couldn't import theme", isPresented: $showImportError, presenting: importError) { _ in
            Button("OK", role: .cancel) {}
        } message: { error in
            Text(error)
        }
        .task {
            await loadThemes()
        }
    }

    private func importTheme() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        if let itermcolors = UTType(filenameExtension: "itermcolors") {
            panel.allowedContentTypes = [itermcolors]
        }
        panel.message = "Choose an iTerm2 .itermcolors file to import"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let userThemes = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/ghostty/themes", isDirectory: true)
        do {
            try ThemeImport.importTheme(from: url, intoUserThemesDir: userThemes)
            // Refresh the library so the new theme appears in the grid.
            Task {
                await ThemeLibrary.shared.resetCache()
                await loadThemes()
            }
        } catch let error as ThemeImport.ImportError {
            importError = error.description
            showImportError = true
        } catch {
            importError = String(describing: error)
            showImportError = true
        }
    }

    // MARK: - Sections

    private func previewHeader(theme: Theme) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(theme.name)
                    .font(.headline)
                    .lineLimit(1)
                Text(theme.isDark ? "Dark" : "Light")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(Capsule().fill(Color(NSColor.controlBackgroundColor)))
                Text(theme.source.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(Capsule().fill(Color(NSColor.controlBackgroundColor)))
                Spacer(minLength: 0)
            }
            TerminalPreview(theme: theme)
                .frame(height: 170)
        }
    }

    private var filterBar: some View {
        HStack(spacing: 8) {
            ForEach(ThemeFilter.allCases) { f in
                FilterChip(title: f.label, isOn: filter == f) { filter = f }
            }
            Spacer()
            Text("\(filtered.count) of \(themes.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private var loadingState: some View {
        HStack(spacing: 8) {
            ProgressView()
            Text("Loading themes…").foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text("No matching themes")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Actions

    private func loadThemes() async {
        let all = await ThemeLibrary.shared.loadAll()
        await MainActor.run {
            themes = all
            isLoading = false
            // Pre-select the currently configured theme if it exists.
            if selectedName == nil {
                selectedName = preselectedName()
            }
        }
    }

    private func preselectedName() -> String? {
        switch mode {
        case .single:
            store.themePair.single ?? store.themePair.light ?? store.themePair.dark
        case .lightPair:
            store.themePair.light ?? store.themePair.single
        case .darkPair:
            store.themePair.dark ?? store.themePair.single
        }
    }

    private func apply(_ theme: Theme) {
        switch mode {
        case .single:
            store.setThemeSingle(theme.name)
        case .lightPair:
            let dark = store.themePair.dark ?? store.themePair.single ?? theme.name
            store.setThemePair(light: theme.name, dark: dark)
        case .darkPair:
            let light = store.themePair.light ?? store.themePair.single ?? theme.name
            store.setThemePair(light: light, dark: theme.name)
        }
    }
}

// MARK: - Mode + Filter

enum ThemeBrowserMode: Hashable {
    case single
    case lightPair
    case darkPair

    var title: String {
        switch self {
        case .single: "Themes"
        case .lightPair: "Light Theme"
        case .darkPair: "Dark Theme"
        }
    }
}

enum ThemeFilter: String, CaseIterable, Identifiable {
    case all, light, dark, bundled, user

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .all: "All"
        case .light: "Light"
        case .dark: "Dark"
        case .bundled: "Bundled"
        case .user: "User"
        }
    }

    func matches(_ theme: Theme) -> Bool {
        switch self {
        case .all: true
        case .light: !theme.isDark
        case .dark: theme.isDark
        case .bundled: theme.source == .bundled
        case .user: theme.source == .user
        }
    }

    /// Default filter for a given browser mode. Pair-mode pre-filters to the
    /// matching appearance; single mode (match-system off) shows everything.
    static func initial(for mode: ThemeBrowserMode) -> ThemeFilter {
        switch mode {
        case .single: .all
        case .lightPair: .light
        case .darkPair: .dark
        }
    }
}

private struct FilterChip: View {
    let title: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.callout)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(isOn ? Color.accentColor : Color(NSColor.controlBackgroundColor))
                )
                .foregroundStyle(isOn ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }
}
