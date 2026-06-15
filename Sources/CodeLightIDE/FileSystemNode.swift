import AppKit

final class FileSystemNode: NSObject {
    let url: URL
    let name: String
    let isDirectory: Bool

    private(set) var children: [FileSystemNode] = []
    private var childrenLoaded = false
    private var showsHiddenAndIgnored: Bool

    init(url: URL, showsHiddenAndIgnored: Bool) {
        self.url = url
        self.name = url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent
        self.showsHiddenAndIgnored = showsHiddenAndIgnored

        var isDirectoryValue: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectoryValue)
        self.isDirectory = isDirectoryValue.boolValue

        super.init()
    }

    func resetVisibility(_ showsHiddenAndIgnored: Bool) {
        self.showsHiddenAndIgnored = showsHiddenAndIgnored
        childrenLoaded = false
        children.removeAll()
    }

    func loadChildrenIfNeeded() {
        guard isDirectory, !childrenLoaded else { return }
        childrenLoaded = true

        let keys: [URLResourceKey] = [
            .isDirectoryKey,
            .isRegularFileKey,
            .isPackageKey,
            .isHiddenKey,
            .localizedNameKey
        ]

        let urls: [URL]
        do {
            urls = try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: keys,
                options: [.skipsPackageDescendants]
            )
        } catch {
            children = []
            return
        }

        children = urls
            .filter { shouldShow($0) }
            .map { FileSystemNode(url: $0, showsHiddenAndIgnored: showsHiddenAndIgnored) }
            .sorted { left, right in
                if left.isDirectory != right.isDirectory {
                    return left.isDirectory && !right.isDirectory
                }
                return left.name.localizedStandardCompare(right.name) == .orderedAscending
            }
    }

    private func shouldShow(_ url: URL) -> Bool {
        if showsHiddenAndIgnored {
            return true
        }

        let name = url.lastPathComponent
        if name.hasPrefix(".") {
            return false
        }

        return !FileIndex.shouldIgnore(name: name)
    }
}
