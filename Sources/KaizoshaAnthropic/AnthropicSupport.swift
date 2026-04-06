import Foundation
import KaizoshaProvider

package struct AnthropicCapabilityProfile: Sendable, Hashable {
    package var capabilities: ModelCapabilities
    package var supportsCodeExecution: Bool
}

package enum AnthropicCapabilityResolver {
    package static func profile(for modelID: String) -> AnthropicCapabilityProfile {
        let normalized = modelID.lowercased()
        let isClaudeModel = normalized.contains("claude")
        let supportsVision = isClaude3Family(normalized) || isClaude4Family(normalized)
        let supportsDocuments = isClaude35Family(normalized) || isClaude37Family(normalized) || isClaude4Family(normalized)
        let supportsCodeExecution = isClaude37Family(normalized) || isClaude35HaikuFamily(normalized) || isClaude4Family(normalized)

        return AnthropicCapabilityProfile(
            capabilities: ModelCapabilities(
                supportsStreaming: isClaudeModel,
                supportsToolCalling: isClaudeModel,
                supportsStructuredOutput: isClaudeModel,
                supportsImageInput: supportsVision,
                supportsAudioInput: false,
                supportsFileInput: supportsDocuments,
                supportsReasoningControls: false
            ),
            supportsCodeExecution: supportsCodeExecution
        )
    }

    private static func isClaude35Family(_ normalized: String) -> Bool {
        normalized.contains("claude-3-5")
    }

    private static func isClaude35HaikuFamily(_ normalized: String) -> Bool {
        normalized.contains("claude-3-5-haiku")
    }

    private static func isClaude37Family(_ normalized: String) -> Bool {
        normalized.contains("claude-3-7")
    }

    private static func isClaude3Family(_ normalized: String) -> Bool {
        normalized.contains("claude-3")
    }

    private static func isClaude4Family(_ normalized: String) -> Bool {
        normalized.contains("claude-4")
            || normalized.contains("claude-opus-4")
            || normalized.contains("claude-sonnet-4")
            || normalized.contains("claude-haiku-4")
    }
}
