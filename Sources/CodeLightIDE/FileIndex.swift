import Foundation

struct FileIndexItem {
    let url: URL
    let relativePath: String

    var fileName: String {
        url.lastPathComponent
    }
}

enum FileIndex {
    static func files(
        under root: URL,
        showsHiddenAndIgnored: Bool
    ) -> [FileIndexItem] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .isRegularFileKey, .isPackageKey, .isHiddenKey]
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsPackageDescendants]
        ) else {
            return []
        }

        var items: [FileIndexItem] = []

        for case let url as URL in enumerator {
            let name = url.lastPathComponent
            if !showsHiddenAndIgnored, shouldIgnore(name: name) {
                enumerator.skipDescendants()
                continue
            }

            guard let values = try? url.resourceValues(forKeys: Set(keys)) else { continue }

            if values.isDirectory == true {
                continue
            }

            guard values.isRegularFile == true else { continue }

            items.append(
                FileIndexItem(
                    url: url,
                    relativePath: relativePath(for: url, root: root)
                )
            )

            if items.count >= 20_000 {
                break
            }
        }

        return items.sorted {
            $0.relativePath.localizedStandardCompare($1.relativePath) == .orderedAscending
        }
    }

    static func matches(_ query: String, in items: [FileIndexItem], limit: Int = 80) -> [FileIndexItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return Array(items.prefix(limit))
        }

        return items
            .compactMap { item -> (item: FileIndexItem, score: Int)? in
                guard let score = fuzzyScore(query: trimmed, candidate: item.relativePath) else { return nil }
                return (item, score)
            }
            .sorted {
                if $0.score != $1.score {
                    return $0.score > $1.score
                }
                return $0.item.relativePath.count < $1.item.relativePath.count
            }
            .prefix(limit)
            .map(\.item)
    }

    static func relativePath(for url: URL, root: URL) -> String {
        let rootPath = root.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        guard path.hasPrefix(rootPath) else { return url.lastPathComponent }

        let start = path.index(path.startIndex, offsetBy: rootPath.count)
        return path[start...].trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    static func shouldIgnore(name: String) -> Bool {
        if name.hasPrefix(".") {
            return true
        }
        return ignoredFolderNames.contains(name)
    }

    private static func fuzzyScore(query: String, candidate: String) -> Int? {
        let query = query.lowercased()
        let candidate = candidate.lowercased()

        if candidate == query {
            return 10_000
        }
        if candidate.hasSuffix("/" + query) || candidate == query {
            return 8_500
        }
        if candidate.contains(query) {
            return 6_000 - candidate.count
        }

        var score = 0
        var previousMatchIndex: String.Index?
        var searchStart = candidate.startIndex

        for character in query {
            guard let matchIndex = candidate[searchStart...].firstIndex(of: character) else {
                return nil
            }

            if let previousMatchIndex, candidate.index(after: previousMatchIndex) == matchIndex {
                score += 14
            } else {
                score += 6
            }

            if matchIndex == candidate.startIndex || candidate[candidate.index(before: matchIndex)] == "/" {
                score += 16
            }

            previousMatchIndex = matchIndex
            searchStart = candidate.index(after: matchIndex)
        }

        return score - candidate.count / 4
    }

    private static let ignoredFolderNames: Set<String> = [
        "node_modules",
        "DerivedData",
        ".build",
        ".git",
        ".svn",
        ".hg",
        ".idea",
        ".vscode",
        "dist",
        "Pods",
        "vendor"
    ]
}
