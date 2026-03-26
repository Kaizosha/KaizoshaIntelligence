import Foundation

/// A lightweight JSON representation used for provider payloads and tool results.
public enum JSONValue: Sendable, Hashable, Codable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    /// Creates a JSON value from an encodable Swift value.
    public static func encode<T: Encodable>(_ value: T) throws -> JSONValue {
        let data = try JSONEncoder().encode(value)
        return try decode(data)
    }

    /// Decodes a JSON value from raw JSON data.
    public static func decode(_ data: Data) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: data)
    }

    /// Returns the JSON data for this value.
    public func data(prettyPrinted: Bool = false) throws -> Data {
        let encoder = JSONEncoder()
        if prettyPrinted {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }
        return try encoder.encode(self)
    }

    /// Returns a compact JSON string for this value.
    public func compactString() throws -> String {
        let data = try data(prettyPrinted: false)
        guard let string = String(data: data, encoding: .utf8) else {
            throw KaizoshaError.invalidResponse("Unable to create a UTF-8 string from JSON data.")
        }
        return string
    }

    /// Returns the underlying object payload when this value is an object.
    public var objectValue: [String: JSONValue]? {
        guard case .object(let object) = self else { return nil }
        return object
    }

    /// Returns the underlying array payload when this value is an array.
    public var arrayValue: [JSONValue]? {
        guard case .array(let array) = self else { return nil }
        return array
    }

    /// Returns the underlying string payload when this value is a string.
    public var stringValue: String? {
        guard case .string(let string) = self else { return nil }
        return string
    }

    /// Returns the underlying number payload when this value is a number.
    public var numberValue: Double? {
        guard case .number(let number) = self else { return nil }
        return number
    }

    /// Returns the underlying Boolean payload when this value is a Boolean.
    public var boolValue: Bool? {
        guard case .bool(let value) = self else { return nil }
        return value
    }

    /// Returns a merged object value.
    public func mergingObject(with other: JSONValue?) -> JSONValue {
        guard case .object(let left) = self else { return self }
        guard let other, case .object(let right) = other else { return self }

        var merged = left
        for (key, value) in right {
            merged[key] = value
        }
        return .object(merged)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let object = try? container.decode([String: JSONValue].self) {
            self = .object(object)
        } else if let array = try? container.decode([JSONValue].self) {
            self = .array(array)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let boolean = try? container.decode(Bool.self) {
            self = .bool(boolean)
        } else if let integer = try? container.decode(Int.self) {
            self = .number(Double(integer))
        } else if let double = try? container.decode(Double.self) {
            self = .number(double)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported JSON value."
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            if value.rounded() == value {
                try container.encode(Int(value))
            } else {
                try container.encode(value)
            }
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

extension JSONValue {
    package static func fromJSONObject(_ object: Any) throws -> JSONValue {
        let data = try JSONSerialization.data(withJSONObject: object)
        return try decode(data)
    }
}
