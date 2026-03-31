import Foundation
import KaizoshaProvider

package let anthropicServerToolsSentinelKey = "__kaizosha_server_tools"

package struct AnthropicRequestOptionsSplit: Sendable, Hashable {
    package var passthrough: JSONValue?
    package var caching: AnthropicPromptCachingConfiguration
    package var serverTools: [AnthropicServerTool]

    package init(
        passthrough: JSONValue? = nil,
        caching: AnthropicPromptCachingConfiguration = AnthropicPromptCachingConfiguration(),
        serverTools: [AnthropicServerTool] = []
    ) {
        self.passthrough = passthrough
        self.caching = caching
        self.serverTools = serverTools
    }
}

/// An approximate end-user location used to localize Anthropic web-search results.
public struct AnthropicUserLocation: Sendable, Hashable {
    /// The city name.
    public var city: String

    /// The region or state name.
    public var region: String

    /// The country code or country name.
    public var country: String

    /// The IANA timezone identifier.
    public var timezone: String

    /// Creates a user location value.
    public init(city: String, region: String, country: String, timezone: String) {
        self.city = city
        self.region = region
        self.country = country
        self.timezone = timezone
    }

    package var jsonValue: JSONValue {
        .object([
            "type": .string("approximate"),
            "city": .string(city),
            "region": .string(region),
            "country": .string(country),
            "timezone": .string(timezone),
        ])
    }
}

/// An Anthropic server tool definition.
public struct AnthropicServerTool: Sendable, Hashable {
    /// The provider tool type, such as `web_search_20250305`.
    public var type: String

    /// The provider tool name, such as `web_search`.
    public var name: String

    /// Tool-specific configuration.
    public var configuration: JSONValue

    /// Creates a server tool definition.
    public init(type: String, name: String, configuration: JSONValue = .object([:])) {
        self.type = type
        self.name = name
        self.configuration = configuration
    }

    /// Creates Anthropic's stable web-search tool definition.
    public static func webSearch(
        maxUses: Int? = nil,
        allowedDomains: [String] = [],
        blockedDomains: [String] = [],
        userLocation: AnthropicUserLocation? = nil
    ) -> AnthropicServerTool {
        var object: [String: JSONValue] = [:]

        if let maxUses {
            object["max_uses"] = .number(Double(maxUses))
        }
        if allowedDomains.isEmpty == false {
            object["allowed_domains"] = .array(allowedDomains.map(JSONValue.string))
        }
        if blockedDomains.isEmpty == false {
            object["blocked_domains"] = .array(blockedDomains.map(JSONValue.string))
        }
        if let userLocation {
            object["user_location"] = userLocation.jsonValue
        }

        return AnthropicServerTool(
            type: "web_search_20250305",
            name: "web_search",
            configuration: .object(object)
        )
    }

    package var jsonValue: JSONValue {
        JSONValue
            .object([
                "type": .string(type),
                "name": .string(name),
            ])
            .mergingObject(with: configuration)
    }
}

package enum AnthropicServerToolsParser {
    package static func split(from providerOptions: JSONValue?) -> (passthrough: JSONValue?, serverTools: [AnthropicServerTool]) {
        guard let object = providerOptions?.objectValue else {
            return (providerOptions, [])
        }

        let serverTools = (object[anthropicServerToolsSentinelKey]?.arrayValue ?? []).compactMap(parseServerTool)
        var passthrough = object
        passthrough.removeValue(forKey: anthropicServerToolsSentinelKey)
        return (passthrough.isEmpty ? nil : .object(passthrough), serverTools)
    }

    private static func parseServerTool(_ value: JSONValue) -> AnthropicServerTool? {
        guard let object = value.objectValue,
              let type = object["type"]?.stringValue,
              let name = object["name"]?.stringValue
        else {
            return nil
        }

        var configuration = object
        configuration.removeValue(forKey: "type")
        configuration.removeValue(forKey: "name")
        return AnthropicServerTool(type: type, name: name, configuration: .object(configuration))
    }
}

package enum AnthropicRequestOptionsParser {
    package static func split(from providerOptions: JSONValue?) -> AnthropicRequestOptionsSplit {
        let cachingSplit = AnthropicPromptCachingParser.split(from: providerOptions)
        let serverToolsSplit = AnthropicServerToolsParser.split(from: cachingSplit.passthrough)
        return AnthropicRequestOptionsSplit(
            passthrough: serverToolsSplit.passthrough,
            caching: cachingSplit.caching,
            serverTools: serverToolsSplit.serverTools
        )
    }
}

package enum AnthropicServerToolValidator {
    package static func validate(
        _ serverTools: [AnthropicServerTool],
        alongside customTools: ToolRegistry,
        modelID: String,
        capabilities: ModelCapabilities
    ) throws {
        guard serverTools.isEmpty == false else { return }

        guard capabilities.supportsToolCalling else {
            throw KaizoshaError.unsupportedCapability(modelID: modelID, capability: "Anthropic server tools")
        }

        let names = customTools.tools.map(\.name) + serverTools.map(\.name)
        if Set(names).count != names.count {
            throw KaizoshaError.invalidRequest("Anthropic tool names must be unique across custom tools and server tools.")
        }

        for serverTool in serverTools {
            if serverTool.type == "web_search_20260209" {
                throw KaizoshaError.invalidRequest(
                    "Anthropic dynamic web search requires the code execution tool, which is not yet exposed by KaizoshaAnthropic."
                )
            }

            if serverTool.type == "web_search_20250305",
               let object = serverTool.configuration.objectValue,
               let maxUses = ModelCatalogDecoding.intValue(object["max_uses"]),
               maxUses < 1 {
                throw KaizoshaError.invalidRequest("Anthropic web search maxUses must be at least 1.")
            }
        }
    }
}
