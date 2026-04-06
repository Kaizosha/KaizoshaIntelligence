import Foundation
import KaizoshaProvider

package let anthropicServerToolsSentinelKey = "__kaizosha_server_tools"
package let anthropicContainerIDSentinelKey = "__kaizosha_container_id"
package let anthropicContainerUploadReferenceURI = "anthropic://container-upload"
package let anthropicCodeExecutionWebToolsBeta = "code-execution-web-tools-2026-02-09"

package struct AnthropicRequestOptionsSplit: Sendable, Hashable {
    package var passthrough: JSONValue?
    package var caching: AnthropicPromptCachingConfiguration
    package var serverTools: [AnthropicServerTool]
    package var containerID: String?

    package init(
        passthrough: JSONValue? = nil,
        caching: AnthropicPromptCachingConfiguration = AnthropicPromptCachingConfiguration(),
        serverTools: [AnthropicServerTool] = [],
        containerID: String? = nil
    ) {
        self.passthrough = passthrough
        self.caching = caching
        self.serverTools = serverTools
        self.containerID = containerID
    }
}

/// Anthropic's documented code-execution tool versions.
public enum AnthropicCodeExecutionToolVersion: String, Sendable, Hashable {
    /// The current stable Bash-and-files tool version.
    case bashAndFiles = "code_execution_20250825"
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

    /// Creates Anthropic's stable code-execution tool definition.
    public static func codeExecution(
        version: AnthropicCodeExecutionToolVersion = .bashAndFiles
    ) -> AnthropicServerTool {
        AnthropicServerTool(type: version.rawValue, name: "code_execution")
    }

    package var isCodeExecution: Bool {
        type.hasPrefix("code_execution_")
    }

    package var requiresCodeExecutionWebToolsBeta: Bool {
        type == "web_search_20260209" || type == "web_fetch_20260209"
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
        let containerID = serverToolsSplit.passthrough?.objectValue?[anthropicContainerIDSentinelKey]?.stringValue
        var passthrough = serverToolsSplit.passthrough?.objectValue ?? [:]
        passthrough.removeValue(forKey: anthropicContainerIDSentinelKey)
        return AnthropicRequestOptionsSplit(
            passthrough: passthrough.isEmpty ? nil : .object(passthrough),
            caching: cachingSplit.caching,
            serverTools: serverToolsSplit.serverTools,
            containerID: containerID
        )
    }
}

package enum AnthropicServerToolValidator {
    package static func validate(
        _ serverTools: [AnthropicServerTool],
        alongside customTools: ToolRegistry,
        hasContainerUploadFiles: Bool,
        containerID: String?,
        modelID: String,
        profile: AnthropicCapabilityProfile
    ) throws {
        let hasCodeExecution = serverTools.contains(where: \.isCodeExecution)
        if hasContainerUploadFiles && hasCodeExecution == false {
            throw KaizoshaError.invalidRequest(
                "Anthropic container-upload file references require the Anthropic code execution tool."
            )
        }
        if containerID != nil && hasCodeExecution == false {
            throw KaizoshaError.invalidRequest(
                "Anthropic container reuse requires the Anthropic code execution tool."
            )
        }
        guard serverTools.isEmpty == false else { return }

        guard profile.capabilities.supportsToolCalling else {
            throw KaizoshaError.unsupportedCapability(modelID: modelID, capability: "Anthropic server tools")
        }

        let names = customTools.tools.map(\.name) + serverTools.map(\.name)
        if Set(names).count != names.count {
            throw KaizoshaError.invalidRequest("Anthropic tool names must be unique across custom tools and server tools.")
        }

        for serverTool in serverTools {
            if serverTool.type == "web_search_20260209" {
                throw KaizoshaError.invalidRequest(
                    "Anthropic dynamic web search is still deferred until a dedicated typed Anthropic dynamic web-search surface lands in KaizoshaAnthropic."
                )
            }

            if serverTool.type == "web_search_20250305",
               let object = serverTool.configuration.objectValue,
               let maxUses = ModelCatalogDecoding.intValue(object["max_uses"]),
               maxUses < 1 {
                throw KaizoshaError.invalidRequest("Anthropic web search maxUses must be at least 1.")
            }

            if serverTool.isCodeExecution && profile.supportsCodeExecution == false {
                throw KaizoshaError.unsupportedCapability(modelID: modelID, capability: "Anthropic code execution")
            }
        }
    }
}
