import Foundation

/// A JSON schema-backed output contract for typed model results.
public struct Schema<Value: Decodable & Sendable>: Sendable {
    /// The human-readable schema name.
    public var name: String

    /// The schema description shown to the model.
    public var description: String

    /// The JSON schema payload.
    public var jsonSchema: JSONValue

    /// Creates a schema from a JSON schema document.
    public init(name: String, description: String, jsonSchema: JSONValue) {
        self.name = name
        self.description = description
        self.jsonSchema = jsonSchema
    }

    /// Decodes a strongly typed value from raw JSON data.
    public func decode(_ data: Data) throws -> Value {
        do {
            return try JSONDecoder().decode(Value.self, from: data)
        } catch {
            throw KaizoshaError.decodingFailure("Unable to decode structured output for schema \(name): \(error.localizedDescription)")
        }
    }

    /// Decodes a strongly typed value from model text.
    public func decode(text: String) throws -> Value {
        let extracted = try JSONTextExtractor.extractJSON(from: text)
        return try decode(extracted)
    }
}

package struct StructuredOutputDirective: Sendable, Hashable {
    package var name: String
    package var description: String
    package var schema: JSONValue
}

extension Schema {
    package var directive: StructuredOutputDirective {
        StructuredOutputDirective(
            name: name,
            description: description,
            schema: jsonSchema
        )
    }
}

enum JSONTextExtractor {
    static func extractJSON(from text: String) throws -> Data {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if let direct = trimmed.data(using: .utf8),
           (try? JSONSerialization.jsonObject(with: direct)) != nil {
            return direct
        }

        let unwrapped = unwrapCodeFence(in: trimmed)
        if let fenced = unwrapped.data(using: .utf8),
           (try? JSONSerialization.jsonObject(with: fenced)) != nil {
            return fenced
        }

        if let range = firstJSONRange(in: unwrapped) {
            let candidate = String(unwrapped[range])
            guard let data = candidate.data(using: .utf8) else {
                throw KaizoshaError.decodingFailure("Unable to create UTF-8 data from structured output.")
            }
            return data
        }

        throw KaizoshaError.decodingFailure("The model response did not contain valid JSON.")
    }

    private static func unwrapCodeFence(in text: String) -> String {
        if text.hasPrefix("```"), let closing = text.range(of: "```", options: .backwards), closing.lowerBound > text.startIndex {
            let start = text.index(text.startIndex, offsetBy: 3)
            var content = String(text[start..<closing.lowerBound])
            if content.hasPrefix("json") {
                content.removeFirst(4)
            }
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text
    }

    private static func firstJSONRange(in text: String) -> Range<String.Index>? {
        var stack: [Character] = []
        var start: String.Index?
        var isInsideString = false
        var isEscaped = false

        for index in text.indices {
            let character = text[index]

            if isInsideString {
                if isEscaped {
                    isEscaped = false
                } else if character == "\\" {
                    isEscaped = true
                } else if character == "\"" {
                    isInsideString = false
                }
                continue
            }

            if character == "\"" {
                isInsideString = true
                continue
            }

            if character == "{" || character == "[" {
                if start == nil {
                    start = index
                }
                stack.append(character)
            } else if character == "}" || character == "]" {
                guard let last = stack.last else { continue }
                let matches = (last == "{" && character == "}") || (last == "[" && character == "]")
                guard matches else { continue }
                stack.removeLast()
                if stack.isEmpty, let start {
                    return start..<text.index(after: index)
                }
            }
        }

        return nil
    }
}
