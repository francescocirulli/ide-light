import Foundation

struct OpenRequest {
    let url: URL
    let line: Int?

    init(url: URL, line: Int? = nil) {
        self.url = url
        self.line = line
    }

    static func parse(argument: String) -> OpenRequest? {
        if let url = URL(string: argument), url.scheme == "code-light" {
            return parseCustomURL(url)
        }

        let expanded = NSString(string: argument).expandingTildeInPath
        if FileManager.default.fileExists(atPath: expanded) {
            return OpenRequest(url: URL(fileURLWithPath: expanded))
        }

        guard
            let separator = expanded.lastIndex(of: ":"),
            let line = Int(expanded[expanded.index(after: separator)...]),
            line > 0
        else {
            return nil
        }

        let path = String(expanded[..<separator])
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        return OpenRequest(url: URL(fileURLWithPath: path), line: line)
    }

    static func parseCustomURL(_ url: URL) -> OpenRequest? {
        guard url.scheme == "code-light" else { return nil }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let items = components?.queryItems ?? []
        let fileValue = items.first { $0.name == "file" || $0.name == "path" }?.value
        let lineValue = items.first { $0.name == "line" }?.value

        let path: String?
        if let fileValue, !fileValue.isEmpty {
            path = NSString(string: fileValue).expandingTildeInPath
        } else if !url.path.isEmpty {
            path = NSString(string: url.path).expandingTildeInPath
        } else {
            path = nil
        }

        guard let path, FileManager.default.fileExists(atPath: path) else { return nil }
        let line = lineValue.flatMap(Int.init).flatMap { $0 > 0 ? $0 : nil }
        return OpenRequest(url: URL(fileURLWithPath: path), line: line)
    }
}
