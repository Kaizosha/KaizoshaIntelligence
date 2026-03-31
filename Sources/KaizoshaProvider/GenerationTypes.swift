import Foundation

/// Common reasoning effort levels across providers.
public enum ReasoningEffort: String, Sendable, Hashable {
    case providerDefault = "provider-default"
    case none
    case minimal
    case low
    case medium
    case high
    case xhigh
}

/// Shared generation controls.
public struct GenerationConfig: Sendable, Hashable {
    /// The sampling temperature.
    public var temperature: Double?

    /// The nucleus sampling value.
    public var topP: Double?

    /// The maximum number of output tokens.
    public var maxOutputTokens: Int?

    /// Stop sequences applied to generation.
    public var stopSequences: [String]

    /// The shared reasoning effort.
    public var reasoning: ReasoningEffort

    /// Creates a generation configuration.
    public init(
        temperature: Double? = nil,
        topP: Double? = nil,
        maxOutputTokens: Int? = nil,
        stopSequences: [String] = [],
        reasoning: ReasoningEffort = .providerDefault
    ) {
        self.temperature = temperature
        self.topP = topP
        self.maxOutputTokens = maxOutputTokens
        self.stopSequences = stopSequences
        self.reasoning = reasoning
    }
}

/// Provider-specific namespaced options.
public struct ProviderOptions: Sendable, Hashable {
    private var storage: [String: JSONValue]

    /// Creates an empty option container.
    public init(_ storage: [String: JSONValue] = [:]) {
        self.storage = storage
    }

    /// Stores options under a provider namespace.
    public mutating func set(_ options: JSONValue, for namespace: String) {
        storage[namespace] = options
    }

    /// Returns options stored for a provider namespace.
    public func options(for namespace: String) -> JSONValue? {
        storage[namespace]
    }
}

/// Tool execution behavior for high-level generation helpers.
public enum ToolExecutionStrategy: Sendable, Hashable {
    case manual
    case automaticSingleStep
}

/// A text generation request.
public struct TextGenerationRequest: Sendable {
    /// The provider-neutral input messages.
    public var messages: [Message]

    /// Shared generation controls.
    public var generation: GenerationConfig

    /// Registered tools available to the model.
    public var tools: ToolRegistry

    /// Namespaced provider-specific options.
    public var providerOptions: ProviderOptions

    /// Arbitrary metadata forwarded to tools and observability layers.
    public var metadata: [String: String]

    /// The tool execution strategy used by top-level helpers.
    public var toolExecution: ToolExecutionStrategy

    package var structuredOutput: StructuredOutputDirective?

    /// Creates a request from existing messages.
    public init(
        messages: [Message],
        generation: GenerationConfig = GenerationConfig(),
        tools: ToolRegistry = ToolRegistry(),
        providerOptions: ProviderOptions = ProviderOptions(),
        metadata: [String: String] = [:],
        toolExecution: ToolExecutionStrategy = .manual
    ) {
        self.messages = messages
        self.generation = generation
        self.tools = tools
        self.providerOptions = providerOptions
        self.metadata = metadata
        self.toolExecution = toolExecution
        self.structuredOutput = nil
    }

    /// Creates a request from a plain-text user prompt.
    public init(
        prompt: String,
        generation: GenerationConfig = GenerationConfig(),
        tools: ToolRegistry = ToolRegistry(),
        providerOptions: ProviderOptions = ProviderOptions(),
        metadata: [String: String] = [:],
        toolExecution: ToolExecutionStrategy = .manual
    ) {
        self.init(
            messages: [.user(prompt)],
            generation: generation,
            tools: tools,
            providerOptions: providerOptions,
            metadata: metadata,
            toolExecution: toolExecution
        )
    }
}

/// Token usage metadata.
public struct Usage: Sendable, Hashable {
    /// Input token count.
    public var inputTokens: Int?

    /// Input tokens read from cache when the provider exposes cache usage.
    public var cacheReadInputTokens: Int?

    /// Input tokens written to cache when the provider exposes cache usage.
    public var cacheCreationInputTokens: Int?

    /// Output token count.
    public var outputTokens: Int?

    /// Total token count.
    public var totalTokens: Int?

    /// Creates usage metadata.
    public init(
        inputTokens: Int? = nil,
        cacheReadInputTokens: Int? = nil,
        cacheCreationInputTokens: Int? = nil,
        outputTokens: Int? = nil,
        totalTokens: Int? = nil
    ) {
        self.inputTokens = inputTokens
        self.cacheReadInputTokens = cacheReadInputTokens
        self.cacheCreationInputTokens = cacheCreationInputTokens
        self.outputTokens = outputTokens
        self.totalTokens = totalTokens
    }
}

/// The reason a generation completed.
public enum FinishReason: String, Sendable, Hashable {
    case stop
    case length
    case toolCalls = "tool-calls"
    case contentFilter = "content-filter"
    case error
    case unknown
}

/// A text generation response.
public struct TextGenerationResponse: Sendable {
    /// The model identifier.
    public var modelID: String

    /// The assistant message produced by the model.
    public var message: Message

    /// The flattened text response.
    public var text: String

    /// Tool calls produced during generation.
    public var toolInvocations: [ToolInvocation]

    /// Tool results attached by high-level helpers.
    public var toolResults: [ToolResult]

    /// Usage information, when available.
    public var usage: Usage?

    /// The completion reason.
    public var finishReason: FinishReason

    /// Raw provider payload metadata, when available.
    public var rawPayload: JSONValue?

    /// Creates a text generation response.
    public init(
        modelID: String,
        message: Message,
        text: String,
        toolInvocations: [ToolInvocation] = [],
        toolResults: [ToolResult] = [],
        usage: Usage? = nil,
        finishReason: FinishReason = .unknown,
        rawPayload: JSONValue? = nil
    ) {
        self.modelID = modelID
        self.message = message
        self.text = text
        self.toolInvocations = toolInvocations
        self.toolResults = toolResults
        self.usage = usage
        self.finishReason = finishReason
        self.rawPayload = rawPayload
    }
}

extension TextGenerationResponse {
    package func appending(toolResults results: [ToolResult]) -> TextGenerationResponse {
        TextGenerationResponse(
            modelID: modelID,
            message: message,
            text: text,
            toolInvocations: toolInvocations,
            toolResults: toolResults,
            usage: usage,
            finishReason: finishReason,
            rawPayload: rawPayload
        )
    }

    package func merging(previous: TextGenerationResponse, toolResults results: [ToolResult]) -> TextGenerationResponse {
        TextGenerationResponse(
            modelID: modelID,
            message: message,
            text: text,
            toolInvocations: previous.toolInvocations + toolInvocations,
            toolResults: previous.toolResults + results + toolResults,
            usage: usage ?? previous.usage,
            finishReason: finishReason,
            rawPayload: rawPayload ?? previous.rawPayload
        )
    }
}

/// A typed structured generation response.
public struct StructuredGenerationResponse<Value: Sendable>: Sendable {
    /// The decoded value.
    public var value: Value

    /// The raw model text.
    public var rawText: String

    /// The underlying text response.
    public var response: TextGenerationResponse

    /// Creates a structured generation response.
    public init(value: Value, rawText: String, response: TextGenerationResponse) {
        self.value = value
        self.rawText = rawText
        self.response = response
    }
}

/// A structured generation streaming event.
public enum StructuredGenerationEvent<Value: Sendable>: Sendable {
    case status(String)
    case textDelta(String)
    case toolCall(ToolInvocation)
    case toolResult(ToolResult)
    case usage(Usage)
    case value(Value)
    case finished(FinishReason)
}

/// A text embedding request.
public struct EmbeddingRequest: Sendable, Hashable {
    /// The texts to embed.
    public var texts: [String]

    /// Namespaced provider-specific options.
    public var providerOptions: ProviderOptions

    /// Request metadata.
    public var metadata: [String: String]

    /// Creates an embedding request.
    public init(
        texts: [String],
        providerOptions: ProviderOptions = ProviderOptions(),
        metadata: [String: String] = [:]
    ) {
        self.texts = texts
        self.providerOptions = providerOptions
        self.metadata = metadata
    }
}

/// An embedding response.
public struct EmbeddingResponse: Sendable, Hashable {
    /// The model identifier.
    public var modelID: String

    /// The embedding vectors.
    public var embeddings: [[Double]]

    /// Usage information.
    public var usage: Usage?

    /// Creates an embedding response.
    public init(modelID: String, embeddings: [[Double]], usage: Usage? = nil) {
        self.modelID = modelID
        self.embeddings = embeddings
        self.usage = usage
    }
}

/// An image generation request.
public struct ImageGenerationRequest: Sendable, Hashable {
    /// The text prompt.
    public var prompt: String

    /// The requested image size.
    public var size: String?

    /// The number of images requested.
    public var count: Int

    /// Namespaced provider-specific options.
    public var providerOptions: ProviderOptions

    /// Request metadata.
    public var metadata: [String: String]

    /// Creates an image generation request.
    public init(
        prompt: String,
        size: String? = nil,
        count: Int = 1,
        providerOptions: ProviderOptions = ProviderOptions(),
        metadata: [String: String] = [:]
    ) {
        self.prompt = prompt
        self.size = size
        self.count = count
        self.providerOptions = providerOptions
        self.metadata = metadata
    }
}

/// A generated image artifact.
public struct GeneratedImage: Sendable, Hashable {
    /// The image data.
    public var data: Data

    /// The MIME type for the image.
    public var mimeType: String

    /// The revised prompt, when a provider supplies one.
    public var revisedPrompt: String?

    /// Creates a generated image artifact.
    public init(data: Data, mimeType: String = "image/png", revisedPrompt: String? = nil) {
        self.data = data
        self.mimeType = mimeType
        self.revisedPrompt = revisedPrompt
    }
}

/// An image generation response.
public struct ImageGenerationResponse: Sendable, Hashable {
    /// The model identifier.
    public var modelID: String

    /// The generated images.
    public var images: [GeneratedImage]

    /// Creates an image generation response.
    public init(modelID: String, images: [GeneratedImage]) {
        self.modelID = modelID
        self.images = images
    }
}

/// Output audio formats for speech synthesis.
public enum AudioFormat: String, Sendable, Hashable {
    case mp3
    case wav
    case aac
    case flac
    case opus
    case pcm16
}

/// A speech generation request.
public struct SpeechGenerationRequest: Sendable, Hashable {
    /// The text prompt to synthesize.
    public var prompt: String

    /// The preferred voice.
    public var voice: String

    /// The output format.
    public var format: AudioFormat

    /// Namespaced provider-specific options.
    public var providerOptions: ProviderOptions

    /// Request metadata.
    public var metadata: [String: String]

    /// Creates a speech generation request.
    public init(
        prompt: String,
        voice: String,
        format: AudioFormat = .mp3,
        providerOptions: ProviderOptions = ProviderOptions(),
        metadata: [String: String] = [:]
    ) {
        self.prompt = prompt
        self.voice = voice
        self.format = format
        self.providerOptions = providerOptions
        self.metadata = metadata
    }
}

/// A speech generation response.
public struct SpeechGenerationResponse: Sendable, Hashable {
    /// The model identifier.
    public var modelID: String

    /// The generated audio bytes.
    public var audio: Data

    /// The MIME type for the audio.
    public var mimeType: String

    /// Creates a speech generation response.
    public init(modelID: String, audio: Data, mimeType: String) {
        self.modelID = modelID
        self.audio = audio
        self.mimeType = mimeType
    }
}

/// A transcription request.
public struct TranscriptionRequest: Sendable, Hashable {
    /// The audio data to transcribe.
    public var audio: Data

    /// The original file name.
    public var fileName: String

    /// The source MIME type.
    public var mimeType: String

    /// Optional prompt context.
    public var prompt: String?

    /// Optional language hint.
    public var language: String?

    /// Namespaced provider-specific options.
    public var providerOptions: ProviderOptions

    /// Request metadata.
    public var metadata: [String: String]

    /// Creates a transcription request.
    public init(
        audio: Data,
        fileName: String,
        mimeType: String = "audio/wav",
        prompt: String? = nil,
        language: String? = nil,
        providerOptions: ProviderOptions = ProviderOptions(),
        metadata: [String: String] = [:]
    ) {
        self.audio = audio
        self.fileName = fileName
        self.mimeType = mimeType
        self.prompt = prompt
        self.language = language
        self.providerOptions = providerOptions
        self.metadata = metadata
    }
}

/// A transcription segment.
public struct TranscriptionSegment: Sendable, Hashable {
    /// The segment start time in seconds.
    public var startTime: Double

    /// The segment end time in seconds.
    public var endTime: Double

    /// The segment text.
    public var text: String

    /// Creates a transcription segment.
    public init(startTime: Double, endTime: Double, text: String) {
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
    }
}

/// A transcription response.
public struct TranscriptionResponse: Sendable, Hashable {
    /// The model identifier.
    public var modelID: String

    /// The transcript text.
    public var text: String

    /// Segments returned by the provider.
    public var segments: [TranscriptionSegment]

    /// Creates a transcription response.
    public init(modelID: String, text: String, segments: [TranscriptionSegment] = []) {
        self.modelID = modelID
        self.text = text
        self.segments = segments
    }
}
