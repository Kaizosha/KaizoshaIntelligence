import Foundation

/// Capability metadata exposed by model adapters.
public struct ModelCapabilities: Sendable, Hashable {
    /// Whether the model supports streaming text generation.
    public var supportsStreaming: Bool

    /// Whether the model supports tool calling.
    public var supportsToolCalling: Bool

    /// Whether the model supports structured JSON output.
    public var supportsStructuredOutput: Bool

    /// Whether the model supports image prompt parts.
    public var supportsImageInput: Bool

    /// Whether the model supports audio prompt parts.
    public var supportsAudioInput: Bool

    /// Whether the model supports file prompt parts.
    public var supportsFileInput: Bool

    /// Whether the embedding model supports more than one text per request.
    public var supportsBatchEmbeddings: Bool

    /// Whether the image model supports generating more than one image.
    public var supportsMultipleImageOutputs: Bool

    /// The supported speech output formats for speech synthesis models.
    public var supportedSpeechFormats: Set<AudioFormat>

    /// Whether the transcription model supports prompt hints.
    public var supportsTranscriptionPrompt: Bool

    /// Whether the transcription model supports language hints.
    public var supportsTranscriptionLanguageHint: Bool

    /// Whether the model exposes provider-level reasoning controls.
    public var supportsReasoningControls: Bool

    /// Creates a capability description for a model.
    public init(
        supportsStreaming: Bool = false,
        supportsToolCalling: Bool = false,
        supportsStructuredOutput: Bool = false,
        supportsImageInput: Bool = false,
        supportsAudioInput: Bool = false,
        supportsFileInput: Bool = false,
        supportsBatchEmbeddings: Bool = false,
        supportsMultipleImageOutputs: Bool = false,
        supportedSpeechFormats: Set<AudioFormat> = [],
        supportsTranscriptionPrompt: Bool = false,
        supportsTranscriptionLanguageHint: Bool = false,
        supportsReasoningControls: Bool = false
    ) {
        self.supportsStreaming = supportsStreaming
        self.supportsToolCalling = supportsToolCalling
        self.supportsStructuredOutput = supportsStructuredOutput
        self.supportsImageInput = supportsImageInput
        self.supportsAudioInput = supportsAudioInput
        self.supportsFileInput = supportsFileInput
        self.supportsBatchEmbeddings = supportsBatchEmbeddings
        self.supportsMultipleImageOutputs = supportsMultipleImageOutputs
        self.supportedSpeechFormats = supportedSpeechFormats
        self.supportsTranscriptionPrompt = supportsTranscriptionPrompt
        self.supportsTranscriptionLanguageHint = supportsTranscriptionLanguageHint
        self.supportsReasoningControls = supportsReasoningControls
    }
}

package enum CapabilityValidator {
    package static func validate(
        _ request: TextGenerationRequest,
        for model: any LanguageModel,
        streaming: Bool
    ) throws {
        let capabilities = model.capabilities

        if streaming, capabilities.supportsStreaming == false {
            throw KaizoshaError.unsupportedCapability(modelID: model.id, capability: "streaming")
        }

        if request.tools.isEmpty == false, capabilities.supportsToolCalling == false {
            throw KaizoshaError.unsupportedCapability(modelID: model.id, capability: "tool calling")
        }

        if request.structuredOutput != nil, capabilities.supportsStructuredOutput == false {
            throw KaizoshaError.unsupportedCapability(modelID: model.id, capability: "structured output")
        }

        if request.generation.reasoning != .providerDefault, capabilities.supportsReasoningControls == false {
            throw KaizoshaError.unsupportedCapability(modelID: model.id, capability: "reasoning controls")
        }

        for message in request.messages {
            for part in message.parts {
                switch part {
                case .text, .toolCall, .toolResult:
                    continue
                case .image:
                    guard capabilities.supportsImageInput else {
                        throw KaizoshaError.unsupportedCapability(modelID: model.id, capability: "image input")
                    }
                case .audio:
                    guard capabilities.supportsAudioInput else {
                        throw KaizoshaError.unsupportedCapability(modelID: model.id, capability: "audio input")
                    }
                case .file:
                    guard capabilities.supportsFileInput else {
                        throw KaizoshaError.unsupportedCapability(modelID: model.id, capability: "file input")
                    }
                }
            }
        }
    }

    package static func validate(_ request: EmbeddingRequest, for model: any EmbeddingModel) throws {
        let capabilities = model.capabilities
        if request.texts.count > 1, capabilities.supportsBatchEmbeddings == false {
            throw KaizoshaError.unsupportedCapability(modelID: model.id, capability: "embedding batching")
        }
    }

    package static func validate(_ request: ImageGenerationRequest, for model: any ImageModel) throws {
        let capabilities = model.capabilities
        if request.count > 1, capabilities.supportsMultipleImageOutputs == false {
            throw KaizoshaError.unsupportedCapability(modelID: model.id, capability: "multiple image outputs")
        }
    }

    package static func validate(_ request: SpeechGenerationRequest, for model: any SpeechModel) throws {
        let capabilities = model.capabilities
        if capabilities.supportedSpeechFormats.isEmpty == false,
           capabilities.supportedSpeechFormats.contains(request.format) == false {
            throw KaizoshaError.unsupportedCapability(
                modelID: model.id,
                capability: "speech format \(request.format.rawValue)"
            )
        }
    }

    package static func validate(_ request: TranscriptionRequest, for model: any TranscriptionModel) throws {
        let capabilities = model.capabilities

        if request.prompt != nil, capabilities.supportsTranscriptionPrompt == false {
            throw KaizoshaError.unsupportedCapability(modelID: model.id, capability: "transcription prompts")
        }

        if request.language != nil, capabilities.supportsTranscriptionLanguageHint == false {
            throw KaizoshaError.unsupportedCapability(modelID: model.id, capability: "transcription language hints")
        }
    }
}
