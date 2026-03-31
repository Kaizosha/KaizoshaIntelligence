import Foundation
import KaizoshaProvider

package let anthropicPromptCachingSentinelKey = "__kaizosha_prompt_caching"

/// Cache lifetime options for Anthropic prompt caching.
public enum AnthropicPromptCacheTTL: Sendable, Hashable {
    /// The default 5-minute cache lifetime.
    case fiveMinutes

    /// The extended 1-hour cache lifetime.
    case oneHour

    package var jsonValue: JSONValue {
        switch self {
        case .fiveMinutes:
            return .null
        case .oneHour:
            return .string("1h")
        }
    }
}

/// A cache-control marker used by Anthropic prompt caching.
public struct AnthropicPromptCacheControl: Sendable, Hashable {
    /// The requested cache lifetime.
    public var ttl: AnthropicPromptCacheTTL

    /// Creates a cache-control marker.
    public init(ttl: AnthropicPromptCacheTTL = .fiveMinutes) {
        self.ttl = ttl
    }

    package var jsonValue: JSONValue {
        var object: [String: JSONValue] = ["type": .string("ephemeral")]
        if ttl == .oneHour {
            object["ttl"] = .string("1h")
        }
        return .object(object)
    }
}

/// An explicit Anthropic cache breakpoint for a tool definition.
public struct AnthropicToolCacheBreakpoint: Sendable, Hashable {
    /// The zero-based tool index in `TextGenerationRequest.tools`.
    public var toolIndex: Int

    /// The cache-control marker to apply.
    public var control: AnthropicPromptCacheControl

    /// Creates a tool breakpoint.
    public init(toolIndex: Int, control: AnthropicPromptCacheControl = AnthropicPromptCacheControl()) {
        self.toolIndex = toolIndex
        self.control = control
    }
}

/// An explicit Anthropic cache breakpoint for a message content block.
public struct AnthropicMessagePartCacheBreakpoint: Sendable, Hashable {
    /// The zero-based message index in `TextGenerationRequest.messages`.
    public var messageIndex: Int

    /// The zero-based part index in that message.
    public var partIndex: Int

    /// The cache-control marker to apply.
    public var control: AnthropicPromptCacheControl

    /// Creates a message-part breakpoint.
    public init(
        messageIndex: Int,
        partIndex: Int,
        control: AnthropicPromptCacheControl = AnthropicPromptCacheControl()
    ) {
        self.messageIndex = messageIndex
        self.partIndex = partIndex
        self.control = control
    }
}

/// Prompt-caching controls for Anthropic requests.
public struct AnthropicPromptCachingOptions: Sendable, Hashable {
    /// Enables Anthropic's automatic top-level caching mode.
    public var automatic: AnthropicPromptCacheControl?

    /// Applies an explicit cache breakpoint to the combined system prompt block.
    public var system: AnthropicPromptCacheControl?

    /// Explicit cache breakpoints for tool definitions.
    public var tools: [AnthropicToolCacheBreakpoint]

    /// Explicit cache breakpoints for message content parts.
    public var messageParts: [AnthropicMessagePartCacheBreakpoint]

    /// Creates prompt-caching options.
    public init(
        automatic: AnthropicPromptCacheControl? = nil,
        system: AnthropicPromptCacheControl? = nil,
        tools: [AnthropicToolCacheBreakpoint] = [],
        messageParts: [AnthropicMessagePartCacheBreakpoint] = []
    ) {
        self.automatic = automatic
        self.system = system
        self.tools = tools
        self.messageParts = messageParts
    }

    package var jsonValue: JSONValue {
        var object: [String: JSONValue] = [:]

        if let automatic {
            object["automatic"] = automatic.jsonValue
        }
        if let system {
            object["system"] = system.jsonValue
        }
        if tools.isEmpty == false {
            object["tools"] = .array(
                tools.map { breakpoint in
                    .object([
                        "tool_index": .number(Double(breakpoint.toolIndex)),
                        "cache_control": breakpoint.control.jsonValue,
                    ])
                }
            )
        }
        if messageParts.isEmpty == false {
            object["message_parts"] = .array(
                messageParts.map { breakpoint in
                    .object([
                        "message_index": .number(Double(breakpoint.messageIndex)),
                        "part_index": .number(Double(breakpoint.partIndex)),
                        "cache_control": breakpoint.control.jsonValue,
                    ])
                }
            )
        }

        return .object(object)
    }
}

package struct AnthropicPromptCachingConfiguration: Sendable, Hashable {
    package var automatic: JSONValue?
    package var system: JSONValue?
    package var tools: [Int: JSONValue]
    package var messageParts: [AnthropicMessagePartKey: JSONValue]

    package init(
        automatic: JSONValue? = nil,
        system: JSONValue? = nil,
        tools: [Int: JSONValue] = [:],
        messageParts: [AnthropicMessagePartKey: JSONValue] = [:]
    ) {
        self.automatic = automatic
        self.system = system
        self.tools = tools
        self.messageParts = messageParts
    }

    package var isEmpty: Bool {
        automatic == nil && system == nil && tools.isEmpty && messageParts.isEmpty
    }
}

package struct AnthropicMessagePartKey: Sendable, Hashable {
    package var messageIndex: Int
    package var partIndex: Int
}

package enum AnthropicPromptCachingParser {
    package static func split(from providerOptions: JSONValue?) -> (passthrough: JSONValue?, caching: AnthropicPromptCachingConfiguration) {
        guard let object = providerOptions?.objectValue else {
            return (providerOptions, AnthropicPromptCachingConfiguration())
        }

        let caching = parseCaching(from: object[anthropicPromptCachingSentinelKey]?.objectValue)
        var passthrough = object
        passthrough.removeValue(forKey: anthropicPromptCachingSentinelKey)
        return (passthrough.isEmpty ? nil : .object(passthrough), caching)
    }

    private static func parseCaching(from object: [String: JSONValue]?) -> AnthropicPromptCachingConfiguration {
        guard let object else { return AnthropicPromptCachingConfiguration() }

        var tools: [Int: JSONValue] = [:]
        for value in object["tools"]?.arrayValue ?? [] {
            guard
                let entry = value.objectValue,
                let index = ModelCatalogDecoding.intValue(entry["tool_index"]),
                let control = entry["cache_control"]
            else {
                continue
            }
            tools[index] = control
        }

        var messageParts: [AnthropicMessagePartKey: JSONValue] = [:]
        for value in object["message_parts"]?.arrayValue ?? [] {
            guard
                let entry = value.objectValue,
                let messageIndex = ModelCatalogDecoding.intValue(entry["message_index"]),
                let partIndex = ModelCatalogDecoding.intValue(entry["part_index"]),
                let control = entry["cache_control"]
            else {
                continue
            }
            messageParts[AnthropicMessagePartKey(messageIndex: messageIndex, partIndex: partIndex)] = control
        }

        return AnthropicPromptCachingConfiguration(
            automatic: object["automatic"],
            system: object["system"],
            tools: tools,
            messageParts: messageParts
        )
    }
}
