import Foundation

/// Result of scoring one row against a query. `matchedFields` is shown in
/// the result list so the user understands *why* something matched.
struct SearchResult: Identifiable, Hashable {
    let row: SearchableRow
    let score: Int
    var id: String { row.id }
}

enum SearchEngine {
    /// Returns rows sorted by descending score. Empty query → empty array
    /// (caller renders the regular nav list).
    @MainActor
    static func results(for rawQuery: String) -> [SearchResult] {
        let query = rawQuery
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !query.isEmpty else { return [] }

        let schemaStore = SchemaStore.shared
        let terms = query.split(whereSeparator: { $0.isWhitespace })
            .map { String($0) }
            .filter { !$0.isEmpty }

        var results: [SearchResult] = []
        for row in SearchCatalog.rows {
            let score = score(row: row, terms: terms, query: query, schemaStore: schemaStore)
            if score > 0 {
                results.append(SearchResult(row: row, score: score))
            }
        }
        results.sort { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            return lhs.row.title < rhs.row.title
        }
        return results
    }

    /// Score a row against all whitespace-separated query terms. All terms
    /// must hit *something* on the row; partial-term matches drop the row.
    /// Within an accepted row, individual term scores sum up.
    @MainActor
    private static func score(
        row: SearchableRow,
        terms: [String],
        query: String,
        schemaStore: SchemaStore
    ) -> Int {
        let title = row.title.lowercased()
        let subtitle = row.subtitle?.lowercased() ?? ""
        let docKey = row.docKey?.lowercased() ?? ""
        let keywordBlob = row.keywords.map { $0.lowercased() }.joined(separator: " ")
        let schemaDocs: String = {
            guard let docKey = row.docKey,
                  let entry = schemaStore.entry(for: docKey)
            else { return "" }
            return entry.docs.lowercased()
        }()

        var total = 0
        for term in terms {
            var termScore = 0
            if title == term {
                termScore = max(termScore, 200)
            } else if title.hasPrefix(term) {
                termScore = max(termScore, 120)
            } else if containsWord(title, term) {
                termScore = max(termScore, 90)
            } else if title.contains(term) {
                termScore = max(termScore, 60)
            }
            if subtitle.contains(term) { termScore = max(termScore, 40) }
            if keywordBlob.contains(term) { termScore = max(termScore, 50) }
            if docKey.contains(term) { termScore = max(termScore, 30) }
            if schemaDocs.contains(term) { termScore = max(termScore, 15) }

            // If *no* field matched this term, the row fails the AND across terms.
            if termScore == 0 { return 0 }
            total += termScore
        }

        // Bonus when the full query string appears verbatim in the title.
        if terms.count > 1 && title.contains(query) {
            total += 50
        }

        return total
    }

    /// `needle` matches a whole word in `haystack` if it sits between word
    /// boundaries (start, end, or non-alphanumeric). Cheap manual scan keeps
    /// this allocation-free.
    private static func containsWord(_ haystack: String, _ needle: String) -> Bool {
        guard !needle.isEmpty else { return false }
        let h = Array(haystack)
        let n = Array(needle)
        guard n.count <= h.count else { return false }
        var i = 0
        while i <= h.count - n.count {
            var match = true
            for j in 0..<n.count where h[i + j] != n[j] {
                match = false
                break
            }
            if match {
                let leftOK = i == 0 || !h[i - 1].isLetter && !h[i - 1].isNumber
                let rightEnd = i + n.count
                let rightOK = rightEnd == h.count || !h[rightEnd].isLetter && !h[rightEnd].isNumber
                if leftOK && rightOK { return true }
            }
            i += 1
        }
        return false
    }
}
