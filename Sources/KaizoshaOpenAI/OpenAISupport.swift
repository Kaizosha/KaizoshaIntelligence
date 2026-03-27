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
        let isEmbedding = normalized.contains("embedding")
        let isImage = normalized.contains("image") || normalized.contains("dall-e")
        let isSpeech = normalized.contains("tts")
        let isTranscription = normalized.contains("transcribe") || normalized.contains("whisper")
        let isRealtime = normalized.contains("realtime")
        let isReasoningModel = normalized.hasPrefix("gpt-5") || normalized.hasPrefix("o1") || normalized.hasPrefix("o3") || normalized.hasPrefix("o4")
        let supportsImageInput = normalized.hasPrefix("gpt-4o") || normalized.hasPrefix("gpt-4.1") || normalized.hasPrefix("gpt-5") || normalized.hasPrefix("o1") || normalized.hasPrefix("o3") || normalized.hasPrefix("o4")
        let supportsAudioInput = normalized.contains("audio") || normalized.contains("transcribe") || normalized.contains("realtime")
        let supportsStructuredOutput = isEmbedding == false && isImage == false && isSpeech == false && isTranscription == false && isRealtime == false
        let supportsToolCalling = supportsStructuredOutput
        let supportsResponses = isEmbedding == false && isImage == false && isSpeech == false && isTranscription == false
        let supportsTextVerbosity = normalized.hasPrefix("gpt-5")
        let supportsSpeechStreaming = isSpeech && normalized != "tts-1" && normalized != "tts-1-hd"
        let supportsSpeechInstructions = supportsSpeechStreaming
        let supportsImageVariations = normalized == "dall-e-2" || normalized.hasPrefix("dall-e-2")

        return OpenAICapabilityProfile(
            capabilities: ModelCapabilities(
                supportsStreaming: supportsResponses,
                supportsToolCalling: supportsToolCalling,
                supportsStructuredOutput: supportsStructuredOutput,
                supportsImageInput: supportsImageInput,
                supportsAudioInput: supportsAudioInput,
                supportsFileInput: supportsResponses,
                supportsBatchEmbeddings: isEmbedding,
                supportsMultipleImageOutputs: isImage,
                supportedSpeechFormats: isSpeech ? [.mp3, .wav, .aac, .flac, .opus, .pcm16] : [],
                supportsTranscriptionPrompt: isTranscription,
                supportsTranscriptionLanguageHint: isTranscription,
                supportsReasoningControls: isReasoningModel
            ),
            supportsResponses: supportsResponses,
            supportsNativeTools: supportsResponses,
            supportsConversationState: supportsResponses,
            supportsInstructions: supportsResponses,
            supportsTextVerbosity: supportsTextVerbosity,
            supportsImageEdits: isImage,
            supportsImageVariations: supportsImageVariations,
            supportsSpeechInstructions: supportsSpeechInstructions,
            supportsSpeechStreaming: supportsSpeechStreaming,
            supportsTranscriptionStreaming: isTranscription && normalized != "whisper-1",
            supportsRealtime: isRealtime
        )
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
