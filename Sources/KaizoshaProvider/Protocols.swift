/// A streaming event emitted by language models.
public enum TextStreamEvent: Sendable {
    case status(String)
    case textDelta(String)
    case toolCall(ToolInvocation)
    case toolResult(ToolResult)
    case usage(Usage)
    case finished(FinishReason)
}

/// A provider-neutral language model contract.
public protocol LanguageModel: Sendable {
    /// The underlying model identifier.
    var id: String { get }

    /// Capability metadata for the model.
    var capabilities: ModelCapabilities { get }

    /// Generates a full response in one request.
    func generate(request: TextGenerationRequest) async throws -> TextGenerationResponse

    /// Streams a response incrementally.
    func stream(request: TextGenerationRequest) -> AsyncThrowingStream<TextStreamEvent, Error>
}

/// A provider-neutral embedding model contract.
public protocol EmbeddingModel: Sendable {
    /// The underlying model identifier.
    var id: String { get }

    /// Capability metadata for the model.
    var capabilities: ModelCapabilities { get }

    /// Generates one or more embeddings.
    func embed(request: EmbeddingRequest) async throws -> EmbeddingResponse
}

/// A provider-neutral image model contract.
public protocol ImageModel: Sendable {
    /// The underlying model identifier.
    var id: String { get }

    /// Capability metadata for the model.
    var capabilities: ModelCapabilities { get }

    /// Generates one or more images.
    func generateImage(request: ImageGenerationRequest) async throws -> ImageGenerationResponse
}

/// A provider-neutral speech synthesis model contract.
public protocol SpeechModel: Sendable {
    /// The underlying model identifier.
    var id: String { get }

    /// Capability metadata for the model.
    var capabilities: ModelCapabilities { get }

    /// Generates speech audio.
    func generateSpeech(request: SpeechGenerationRequest) async throws -> SpeechGenerationResponse
}

/// A provider-neutral transcription model contract.
public protocol TranscriptionModel: Sendable {
    /// The underlying model identifier.
    var id: String { get }

    /// Capability metadata for the model.
    var capabilities: ModelCapabilities { get }

    /// Transcribes the provided audio input.
    func transcribe(request: TranscriptionRequest) async throws -> TranscriptionResponse
}
