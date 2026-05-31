import SwiftUI

struct ContentView: View {
    @Environment(ConfigStore.self) private var store
    @SceneStorage("sidebar.selection") private var selectionRaw: String = SidebarSection.appearance.rawValue

    private var selection: Binding<SidebarSection> {
        Binding(
            get: { SidebarSection(rawValue: selectionRaw) ?? .appearance },
            set: { selectionRaw = $0.rawValue }
        )
    }

    @Environment(\.undoManager) private var undoManager
    @State private var installBannerDismissed: Bool = false
    @State private var schemaBannerDismissed: Bool = false
    @State private var searchText: String = ""

    /// True when schema introspection failed *and* the bundled fallback is too
    /// thin to be useful — the one case where we owe the user an explanation.
    private var showSchemaBanner: Bool {
        SchemaStore.shared.lastError != nil
            && SchemaStore.shared.schema.entries.count < 50
            && !schemaBannerDismissed
    }

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            Sidebar(selection: selection, searchText: $searchText)
        } detail: {
            VStack(spacing: 0) {
                if !store.ghosttyInstalled, !installBannerDismissed {
                    InstallBanner(isDismissed: $installBannerDismissed)
                }
                if showSchemaBanner {
                    Banner(
                        kind: .warning,
                        title: "Couldn't read Ghostty's settings catalog",
                        detail: "Showing built-in defaults. Some option descriptions may be missing.",
                        onDismiss: { schemaBannerDismissed = true }
                    )
                }
                NavigationStack {
                    pane(for: selection.wrappedValue)
                }
            }
            .overlay(alignment: .bottom) {
                if let notice = store.externalEditNotice {
                    Banner(kind: .info, title: notice)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .shadow(radius: 8, y: 2)
                        .padding(12)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: store.externalEditNotice)
        }
        .navigationSplitViewStyle(.balanced)
        .searchable(
            text: $searchText,
            placement: .sidebar,
            prompt: "Search"
        )
        .frame(
            minWidth: 715, idealWidth: 715, maxWidth: 715,
            minHeight: 480, idealHeight: 600
        )
        .background(WindowAccessor { window in
            window.collectionBehavior.insert(.fullScreenNone)
            window.collectionBehavior.remove(.fullScreenPrimary)
            window.standardWindowButton(.zoomButton)?.isEnabled = false
            window.title = ""
            window.titleVisibility = .hidden
        })
        .task {
            store.undoManager = undoManager
            async let schema: () = SchemaStore.shared.loadIfNeeded()
            async let themes: () = store.loadThemeIndex()
            async let version: () = store.loadGhosttyVersion()
            async let defaultKeybinds: () = store.loadDefaultKeybinds()
            await store.load()
            store.startWatching()
            await schema
            await themes
            await version
            await defaultKeybinds
        }
        .onChange(of: undoManager) { _, newValue in
            store.undoManager = newValue
        }
    }

    private func pane(for section: SidebarSection) -> some View {
        // Reload button lives in the toolbar's trailing slot for every pane.
        // The pane header (icon + title + subtitle) is rendered by each pane's
        // .paneToolbar(...) modifier as a content row, not a toolbar item, so
        // it can match the page padding and have no frosted background.
        paneBody(for: section)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    ReloadToolbarButton()
                }
            }
    }

    @ViewBuilder
    private func paneBody(for section: SidebarSection) -> some View {
        switch section {
        case .appearance: AppearancePane()
        case .window: WindowPane()
        case .font: FontPane()
        case .cursor: CursorPane()
        case .keyboard: KeyboardPane()
        case .shell: ShellPane()
        case .clipboardMouse: ClipboardAndMousePane()
        case .general: GeneralPane()
        case .advanced: AdvancedPane()
        case .about: AboutPane()
        }
    }
}

#Preview {
    ContentView()
        .environment(ConfigStore())
}
