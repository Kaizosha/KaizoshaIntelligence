import Foundation

package extension URL {
    func appendingPathComponents(_ path: String) -> URL {
        path
            .split(separator: "/", omittingEmptySubsequences: true)
            .reduce(self) { url, component in
                url.appendingPathComponent(String(component))
            }
    }
}
