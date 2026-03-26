import Foundation

/// A model descriptor returned from a provider's live model catalog.
public struct AvailableModel: Sendable, Hashable, Codable {
    /// The identifier you can pass back into the SDK, such as `gpt-4o-mini`.
    public var id: String

    /// The raw provider-side identifier when it differs from ``id``.
    public var providerIdentifier: String?

    /// The provider namespace that supplied the model entry.
    public var provider: String

    /// A human-readable name for the model, when available.
    public var displayName: String?

    /// A provider-defined model type, such as `language` or `embedding`.
    public var type: String?

    /// The owning organization, when the provider returns it.
    public var ownedBy: String?

    /// The model creation date, when available.
    public var createdAt: Date?

    /// The input context window size, when available.
    public var contextWindow: Int?

    /// The maximum output token count, when available.
    public var maxOutputTokens: Int?

    /// Provider-defined supported methods, such as `generateContent` or `embedContent`.
    public var supportedGenerationMethods: [String]

    /// The original provider payload for advanced use cases.
    public var rawMetadata: JSONValue?

    /// Creates a provider-backed model descriptor.
    public init(
        id: String,
        providerIdentifier: String? = nil,
        provider: String,
        displayName: String? = nil,
        type: String? = nil,
        ownedBy: String? = nil,
        createdAt: Date? = nil,
        contextWindow: Int? = nil,
        maxOutputTokens: Int? = nil,
        supportedGenerationMethods: [String] = [],
        rawMetadata: JSONValue? = nil
    ) {
        self.id = id
        self.providerIdentifier = providerIdentifier
        self.provider = provider
        self.displayName = displayName
        self.type = type
        self.ownedBy = ownedBy
        self.createdAt = createdAt
        self.contextWindow = contextWindow
        self.maxOutputTokens = maxOutputTokens
        self.supportedGenerationMethods = supportedGenerationMethods
        self.rawMetadata = rawMetadata
    }
}

package enum ModelCatalogDecoding {
    package static func intValue(_ value: JSONValue?) -> Int? {
        if let number = value?.numberValue {
            return Int(number)
        }

        if let string = value?.stringValue, let number = Int(string) {
            return number
        }

        return nil
    }

    package static func unixTimestamp(_ value: JSONValue?) -> Date? {
        guard let number = value?.numberValue else { return nil }
        return Date(timeIntervalSince1970: number)
    }

    package static func iso8601Date(_ value: JSONValue?) -> Date? {
        guard let string = value?.stringValue else { return nil }

        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalFormatter.date(from: string) {
            return date
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }

    package static func stringArray(_ value: JSONValue?) -> [String] {
        value?.arrayValue?.compactMap(\.stringValue) ?? []
    }
}
