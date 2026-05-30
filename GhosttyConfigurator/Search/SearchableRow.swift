import Foundation

/// One indexed row in the global search catalog. `id` must be unique across
/// the catalog; `pane` is the destination the search result navigates to.
/// `keywords` are alternate terms the user might type — they don't appear in
/// the UI but they steer scoring (e.g. "transparency" → Background opacity).
struct SearchableRow: Identifiable, Hashable {
    let id: String
    let pane: SidebarSection
    let title: String
    let subtitle: String?
    let docKey: String?
    let keywords: [String]

    init(
        id: String,
        pane: SidebarSection,
        title: String,
        subtitle: String? = nil,
        docKey: String? = nil,
        keywords: [String] = []
    ) {
        self.id = id
        self.pane = pane
        self.title = title
        self.subtitle = subtitle
        self.docKey = docKey
        self.keywords = keywords
    }
}
