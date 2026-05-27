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

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            Sidebar(selection: selection)
        } detail: {
            VStack(spacing: 0) {
                if !store.ghosttyInstalled && !installBannerDismissed {
                    InstallBanner(isDismissed: $installBannerDismissed)
                }
                NavigationStack {
                    pane(for: selection.wrappedValue)
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .frame(
            minWidth: 715, idealWidth: 715, maxWidth: 715,
            minHeight: 480, idealHeight: 600
        )
        .background(WindowAccessor { window in
            window.collectionBehavior.insert(.fullScreenNone)
            window.collectionBehavior.remove(.fullScreenPrimary)
            window.standardWindowButton(.zoomButton)?.isEnabled = false
            window.title = "Ghostty Configurator"
        })
        .task {
            store.undoManager = undoManager
            async let schema: () = SchemaStore.shared.loadIfNeeded()
            await store.load()
            store.startWatching()
            await schema
        }
        .onChange(of: undoManager) { _, newValue in
            store.undoManager = newValue
        }
    }

    @ViewBuilder
    private func pane(for section: SidebarSection) -> some View {
        let body = paneBody(for: section)
        body
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    ReloadToolbarButton()
                }
            }
    }

    @ViewBuilder
    private func paneBody(for section: SidebarSection) -> some View {
        switch section {
        case .appearance:       AppearancePane()
        case .window:           WindowPane()
        case .font:             FontPane()
        case .cursor:           CursorPane()
        case .keyboard:         PlaceholderPane(section: section)
        case .shell:            ShellPane()
        case .clipboardMouse:   ClipboardAndMousePane()
        case .general:          GeneralPane()
        case .advanced:         PlaceholderPane(section: section)
        case .about:            AboutPane()
        }
    }
}

#Preview {
    ContentView()
        .environment(ConfigStore())
}
