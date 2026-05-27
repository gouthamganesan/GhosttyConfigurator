import SwiftUI

struct Sidebar: View {
    @Binding var selection: SidebarSection

    var body: some View {
        List(selection: $selection) {
            Section { ForEach(SidebarSection.visualGroup)   { row($0) } }
            Section { ForEach(SidebarSection.behaviorGroup) { row($0) } }
            Section { ForEach(SidebarSection.systemGroup)   { row($0) } }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 200, ideal: 215, max: 260)
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
