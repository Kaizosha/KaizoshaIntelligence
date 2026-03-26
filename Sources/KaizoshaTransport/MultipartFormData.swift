import Foundation

package struct MultipartFormData: Sendable {
    package struct Part: Sendable {
        package var name: String
        package var fileName: String?
        package var mimeType: String?
        package var data: Data
    }

    package var boundary: String
    private var parts: [Part]

    package init(boundary: String = UUID().uuidString, parts: [Part] = []) {
        self.boundary = boundary
        self.parts = parts
    }

    package mutating func addText(name: String, value: String) {
        parts.append(
            Part(
                name: name,
                fileName: nil,
                mimeType: nil,
                data: Data(value.utf8)
            )
        )
    }

    package mutating func addData(name: String, fileName: String, mimeType: String, data: Data) {
        parts.append(
            Part(
                name: name,
                fileName: fileName,
                mimeType: mimeType,
                data: data
            )
        )
    }

    package var contentType: String {
        "multipart/form-data; boundary=\(boundary)"
    }

    package func data() -> Data {
        var buffer = Data()

        for part in parts {
            buffer.append(Data("--\(boundary)\r\n".utf8))

            if let fileName = part.fileName {
                buffer.append(Data("Content-Disposition: form-data; name=\"\(part.name)\"; filename=\"\(fileName)\"\r\n".utf8))
                if let mimeType = part.mimeType {
                    buffer.append(Data("Content-Type: \(mimeType)\r\n".utf8))
                }
            } else {
                buffer.append(Data("Content-Disposition: form-data; name=\"\(part.name)\"\r\n".utf8))
            }

            buffer.append(Data("\r\n".utf8))
            buffer.append(part.data)
            buffer.append(Data("\r\n".utf8))
        }

        buffer.append(Data("--\(boundary)--\r\n".utf8))
        return buffer
    }
}
