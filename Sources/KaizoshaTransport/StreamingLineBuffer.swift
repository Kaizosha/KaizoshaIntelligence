import Foundation

package struct StreamingLineBuffer {
    private var buffer = Data()

    package init() {}

    package mutating func append(_ data: Data) -> [String] {
        buffer.append(data)
        return drainLines()
    }

    package mutating func finish() -> [String] {
        var lines = drainLines()

        if buffer.isEmpty == false {
            lines.append(Self.decodeLine(buffer))
            buffer.removeAll(keepingCapacity: false)
        }

        return lines
    }

    private mutating func drainLines() -> [String] {
        var lines: [String] = []

        while let newlineIndex = buffer.firstIndex(of: 0x0A) {
            let lineData = Data(buffer[..<newlineIndex])
            lines.append(Self.decodeLine(lineData))
            buffer.removeSubrange(...newlineIndex)
        }

        return lines
    }

    private static func decodeLine(_ data: Data) -> String {
        var data = data
        if data.last == 0x0D {
            data.removeLast()
        }
        return String(decoding: data, as: UTF8.self)
    }
}
