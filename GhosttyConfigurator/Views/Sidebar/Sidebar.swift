import SwiftUI

struct Sidebar: View {
    @Binding var selection: SidebarSection
    @Binding var searchText: String

    var body: some View {
        Group {
            if searchText.isEmpty {
                navList
            } else {
                SearchResultsView(query: searchText) { row in
                    selection = row.pane
                    searchText = ""
                }
            }
        }
        .navigationSplitViewColumnWidth(min: 200, ideal: 215, max: 260)
        .toolbar(removing: .sidebarToggle)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            SidebarFooter()
        }
    }

    private var navList: some View {
        List(selection: $selection) {
            Section { ForEach(SidebarSection.visualGroup)   { row($0) } }
            Section { ForEach(SidebarSection.behaviorGroup) { row($0) } }
            Section { ForEach(SidebarSection.systemGroup)   { row($0) } }
        }
        .listStyle(.sidebar)
    }

    private func row(_ section: SidebarSection) -> some View {
        NavigationLink(value: section) {
            Label {
                Text(section.title)
            } icon: {
                SidebarIcon(symbol: section.symbol, tint: section.tint)
            }
        }
    }
}
