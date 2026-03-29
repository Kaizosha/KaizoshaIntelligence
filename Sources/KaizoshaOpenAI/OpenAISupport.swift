import Foundation
import KaizoshaProvider

/// The prompt cache retention policy used by OpenAI requests.
public enum OpenAIPromptCacheRetention: String, Sendable, Hashable {
    /// Use the provider default in-memory caching behavior.
    case providerDefault = "provider-default"

    /// Request extended prompt caching for up to 24 hours.
    case extended24Hours = "24h"
}

/// The service tier requested from OpenAI.
public enum OpenAIServiceTier: String, Sendable, Hashable {
    case auto
    case `default`
    case flex
    case priority
}

/// The reasoning summary detail requested from OpenAI.
public enum OpenAIReasoningSummary: String, Sendable, Hashable {
    case none
    case auto
    case concise
    case detailed
}

/// The verbosity preference for GPT-5 Responses requests.
public enum OpenAITextVerbosity: String, Sendable, Hashable {
    case low
    case medium
    case high
}

/// The tool selection strategy used by OpenAI Responses requests.
public enum OpenAIToolChoice: Sendable, Hashable {
    case auto
    case none
    case required
    case function(name: String)

    package var jsonValue: JSONValue {
        switch self {
        case .auto:
            return .string("auto")
        case .none:
            return .string("none")
        case .required:
            return .string("required")
        case .function(let name):
            return .object([
                "type": .string("function"),
                "name": .string(name),
            ])
        }
    }
}

/// A native OpenAI tool configuration for the Responses API.
public struct OpenAINativeTool: Sendable, Hashable {
    /// The OpenAI tool type.
    public var type: String

    /// Tool-specific configuration fields.
    public var configuration: JSONValue

    /// Creates a native OpenAI tool configuration.
    public init(type: String, configuration: JSONValue = .object([:])) {
        self.type = type
        self.configuration = configuration
    }

    /// Creates a web search tool definition.
    public static func webSearch(configuration: JSONValue = .object([:])) -> OpenAINativeTool {
        OpenAINativeTool(type: "web_search", configuration: configuration)
    }

    /// Creates a file search tool definition.
    public static func fileSearch(
        vectorStoreIDs: [String] = [],
        maxResults: Int? = nil
    ) -> OpenAINativeTool {
        var object: [String: JSONValue] = [:]
        if vectorStoreIDs.isEmpty == false {
            object["vector_store_ids"] = .array(vectorStoreIDs.map(JSONValue.string))
        }
        if let maxResults {
            object["max_num_results"] = .number(Double(maxResults))
        }
        return OpenAINativeTool(type: "file_search", configuration: .object(object))
    }

    /// Creates a code interpreter tool definition.
    public static func codeInterpreter(configuration: JSONValue = .object([:])) -> OpenAINativeTool {
        OpenAINativeTool(type: "code_interpreter", configuration: configuration)
    }

    /// Creates an image generation tool definition.
    public static func imageGeneration(configuration: JSONValue = .object([:])) -> OpenAINativeTool {
        OpenAINativeTool(type: "image_generation", configuration: configuration)
    }

    /// Creates a remote MCP tool definition.
    public static func mcp(serverLabel: String, serverURL: URL, headers: [String: String] = [:]) -> OpenAINativeTool {
        var object: [String: JSONValue] = [
            "server_label": .string(serverLabel),
            "server_url": .string(serverURL.absoluteString),
        ]

        if headers.isEmpty == false {
            object["headers"] = .object(headers.mapValues(JSONValue.string))
        }

        return OpenAINativeTool(type: "mcp", configuration: .object(object))
    }

    package var jsonValue: JSONValue {
        JSONValue.object(["type": .string(type)]).mergingObject(with: configuration)
    }
}

package struct OpenAICapabilityProfile: Sendable, Hashable {
    package var capabilities: ModelCapabilities
    package var supportsResponses: Bool
    package var supportsNativeTools: Bool
    package var supportsConversationState: Bool
    package var supportsInstructions: Bool
    package var supportsTextVerbosity: Bool
    package var supportsImageEdits: Bool
    package var supportsImageVariations: Bool
    package var supportsSpeechInstructions: Bool
    package var supportsSpeechStreaming: Bool
    package var supportsTranscriptionStreaming: Bool
    package var supportsRealtime: Bool
}

package enum OpenAICapabilityResolver {
    package static func profile(for modelID: String) -> OpenAICapabilityProfile {
        let normalized = modelID.lowercased()
        let family = OpenAIModelFamily(normalizedID: normalized)
        let supportsResponses = family.supportsResponses
        let supportsStructuredOutput = family.supportsStructuredOutput
        let supportsToolCalling = family.supportsToolCalling
        let supportsImageInput = family.supportsImageInput
        let supportsAudioInput = family.supportsAudioInput
        let supportsTextVerbosity = family.supportsTextVerbosity
        let supportsSpeechStreaming = family.supportsSpeechStreaming
        let supportsSpeechInstructions = family.supportsSpeechInstructions
        let supportsImageVariations = family.supportsImageVariations
        let supportsReasoningControls = family.supportsReasoningControls

        return OpenAICapabilityProfile(
            capabilities: ModelCapabilities(
                supportsStreaming: supportsResponses,
                supportsToolCalling: supportsToolCalling,
                supportsStructuredOutput: supportsStructuredOutput,
                supportsImageInput: supportsImageInput,
                supportsAudioInput: supportsAudioInput,
                supportsFileInput: family.supportsFileInput,
                supportsBatchEmbeddings: family.isEmbedding,
                supportsMultipleImageOutputs: family.isImage,
                supportedSpeechFormats: family.isSpeech ? [.mp3, .wav, .aac, .flac, .opus, .pcm16] : [],
                supportsTranscriptionPrompt: family.isTranscription,
                supportsTranscriptionLanguageHint: family.isTranscription,
                supportsReasoningControls: supportsReasoningControls
            ),
            supportsResponses: supportsResponses,
            supportsNativeTools: family.supportsNativeTools,
            supportsConversationState: supportsResponses,
            supportsInstructions: supportsResponses,
            supportsTextVerbosity: supportsTextVerbosity,
            supportsImageEdits: family.isImage,
            supportsImageVariations: supportsImageVariations,
            supportsSpeechInstructions: supportsSpeechInstructions,
            supportsSpeechStreaming: supportsSpeechStreaming,
            supportsTranscriptionStreaming: family.isTranscription && normalized != "whisper-1",
            supportsRealtime: family.isRealtime
        )
    }
}

private struct OpenAIModelFamily {
    let normalizedID: String

    var isEmbedding: Bool {
        normalizedID.contains("embedding")
    }

    var isImage: Bool {
        normalizedID.contains("dall-e") || normalizedID.contains("gpt-image") || normalizedID == "image"
    }

    var isSpeech: Bool {
        normalizedID.contains("tts")
    }

    var isTranscription: Bool {
        normalizedID.contains("transcribe") || normalizedID.contains("whisper")
    }

    var isRealtime: Bool {
        normalizedID.contains("realtime")
    }

    var isAudioResponsesModel: Bool {
        normalizedID.contains("audio-preview") || normalizedID.hasPrefix("gpt-audio")
    }

    var isResponsesTextFamily: Bool {
        if isEmbedding || isImage || isSpeech || isTranscription || isRealtime || isAudioResponsesModel {
            return false
        }

        return normalizedID.hasPrefix("gpt-4o")
            || normalizedID.hasPrefix("chatgpt-4o")
            || normalizedID.hasPrefix("gpt-4.1")
            || normalizedID.hasPrefix("gpt-5")
            || normalizedID.hasPrefix("gpt-")
            || normalizedID.hasPrefix("o1")
            || normalizedID.hasPrefix("o3")
            || normalizedID.hasPrefix("o4")
    }

    var supportsResponses: Bool {
        isResponsesTextFamily || isAudioResponsesModel
    }

    var supportsStructuredOutput: Bool {
        isResponsesTextFamily
    }

    var supportsToolCalling: Bool {
        isResponsesTextFamily || isAudioResponsesModel
    }

    var supportsNativeTools: Bool {
        isResponsesTextFamily
    }

    var supportsImageInput: Bool {
        isResponsesTextFamily && (
            normalizedID.hasPrefix("gpt-4o")
                || normalizedID.hasPrefix("chatgpt-4o")
                || normalizedID.hasPrefix("gpt-4.1")
                || normalizedID.hasPrefix("gpt-5")
                || normalizedID.hasPrefix("o1")
                || normalizedID.hasPrefix("o3")
                || normalizedID.hasPrefix("o4")
        )
    }

    var supportsAudioInput: Bool {
        isAudioResponsesModel
    }

    var supportsFileInput: Bool {
        supportsResponses
    }

    var supportsReasoningControls: Bool {
        isResponsesTextFamily
            && (
                normalizedID.hasPrefix("gpt-5")
                    || normalizedID.hasPrefix("o1")
                    || normalizedID.hasPrefix("o3")
                    || normalizedID.hasPrefix("o4")
            )
    }

    var supportsTextVerbosity: Bool {
        isResponsesTextFamily && normalizedID.hasPrefix("gpt-5")
    }

    var supportsSpeechStreaming: Bool {
        isSpeech && normalizedID != "tts-1" && normalizedID != "tts-1-hd"
    }

    var supportsSpeechInstructions: Bool {
        supportsSpeechStreaming
    }

    var supportsImageVariations: Bool {
        normalizedID == "dall-e-2" || normalizedID.hasPrefix("dall-e-2")
    }
}

package enum OpenAIRequestSupport {
    package static func mimeSubtype(from mimeType: String) -> String {
        let components = mimeType.lowercased().split(separator: "/")
        guard components.count == 2 else { return "wav" }
        return String(components[1]).replacingOccurrences(of: "x-", with: "")
    }

    package static func inferImageMimeType(from bytes: Data) -> String {
        if bytes.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
            return "image/png"
        }
        if bytes.starts(with: [0xFF, 0xD8, 0xFF]) {
            return "image/jpeg"
        }
        if bytes.starts(with: Data("GIF".utf8)) {
            return "image/gif"
        }
        return "application/octet-stream"
    }

    package static func parseUsage(from object: [String: JSONValue]?) -> Usage? {
        guard let object else { return nil }

        let inputTokens = ModelCatalogDecoding.intValue(object["input_tokens"])
            ?? ModelCatalogDecoding.intValue(object["prompt_tokens"])
        let outputTokens = ModelCatalogDecoding.intValue(object["output_tokens"])
            ?? ModelCatalogDecoding.intValue(object["completion_tokens"])
        let totalTokens = ModelCatalogDecoding.intValue(object["total_tokens"])

        if inputTokens == nil, outputTokens == nil, totalTokens == nil {
            return nil
        }

        return Usage(
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            totalTokens: totalTokens
        )
    }

    package static func supportsSpeechInstructions(modelID: String) -> Bool {
        OpenAICapabilityResolver.profile(for: modelID).supportsSpeechInstructions
    }

    package static func supportsSpeechStreaming(modelID: String) -> Bool {
        OpenAICapabilityResolver.profile(for: modelID).supportsSpeechStreaming
    }

    package static func supportsImageVariations(modelID: String) -> Bool {
        OpenAICapabilityResolver.profile(for: modelID).supportsImageVariations
    }

    package static func supportsTextVerbosity(modelID: String) -> Bool {
        OpenAICapabilityResolver.profile(for: modelID).supportsTextVerbosity
    }

    package static func isDiarizationModel(_ modelID: String) -> Bool {
        modelID.lowercased().contains("transcribe-diarize")
    }

    package static func supportedTranscriptionFormats(for modelID: String) -> Set<OpenAITranscriptionResponseFormat> {
        let normalized = modelID.lowercased()

        if normalized == "whisper-1" {
            return [.json, .text, .srt, .verboseJSON, .vtt]
        }

        if isDiarizationModel(modelID) {
            return [.json, .text, .diarizedJSON]
        }

        if normalized.contains("transcribe") {
            return [.json, .text]
        }

        return [.json]
    }

    package static func supportsTranscriptionLogprobs(modelID: String) -> Bool {
        let normalized = modelID.lowercased()
        if isDiarizationModel(modelID) {
            return false
        }
        return normalized.hasPrefix("gpt-4o-transcribe") || normalized.hasPrefix("gpt-4o-mini-transcribe")
    }

    package static func supportsTranscriptionPrompt(modelID: String) -> Bool {
        isDiarizationModel(modelID) == false
    }

    package static func supportsTranscriptionTimestampGranularities(modelID: String) -> Bool {
        modelID.lowercased() == "whisper-1"
    }
}
