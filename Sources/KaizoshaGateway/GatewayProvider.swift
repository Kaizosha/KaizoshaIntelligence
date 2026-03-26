import Foundation
import KaizoshaOpenAI
import KaizoshaProvider
import KaizoshaTransport

/// A provider factory for Vercel AI Gateway-backed models.
public struct GatewayProvider: Sendable {
    /// The provider namespace used in namespaced options.
    public static let namespace = "gateway"

    private let openAICompatible: OpenAIProvider

    /// Creates an AI Gateway provider using the OpenAI-compatible API.
    public init(
        apiKey: String? = ProcessInfo.processInfo.environment["AI_GATEWAY_API_KEY"] ?? ProcessInfo.processInfo.environment["VERCEL_OIDC_TOKEN"],
        baseURL: URL = URL(string: "https://ai-gateway.vercel.sh/v1")!,
        transport: (any HTTPTransport)? = nil,
        retryPolicy: RetryPolicy = .default
    ) throws {
        self.openAICompatible = try OpenAIProvider(
            apiKey: apiKey,
            baseURL: baseURL,
            transport: transport,
            retryPolicy: retryPolicy
        )
    }

    /// Creates a language model handle. Use `vendor/model` identifiers such as `openai/gpt-5.4`.
    public func languageModel(_ id: String) -> GatewayLanguageModel {
        GatewayLanguageModel(id: id, underlying: openAICompatible.languageModel(id))
    }

    /// Creates an embedding model handle.
    public func embeddingModel(_ id: String) -> GatewayEmbeddingModel {
        GatewayEmbeddingModel(id: id, underlying: openAICompatible.embeddingModel(id))
    }

    /// Creates an image model handle.
    public func imageModel(_ id: String) -> GatewayImageModel {
        GatewayImageModel(id: id, underlying: openAICompatible.imageModel(id))
    }
}

/// A Gateway language model backed by the OpenAI-compatible API.
public struct GatewayLanguageModel: LanguageModel, Sendable {
    /// The routed model identifier.
    public let id: String

    /// Capability metadata for the model.
    public let capabilities: ModelCapabilities

    private let underlying: OpenAILanguageModel

    fileprivate init(id: String, underlying: OpenAILanguageModel) {
        self.id = id
        self.capabilities = underlying.capabilities
        self.underlying = underlying
    }

    public func generate(request: TextGenerationRequest) async throws -> TextGenerationResponse {
        try await underlying.generate(request: remap(request))
    }

    public func stream(request: TextGenerationRequest) -> AsyncThrowingStream<TextStreamEvent, Error> {
        underlying.stream(request: remap(request))
    }

    private func remap(_ request: TextGenerationRequest) -> TextGenerationRequest {
        var request = request
        if let gatewayOptions = request.providerOptions.options(for: GatewayProvider.namespace) {
            var options = request.providerOptions
            options.set(gatewayOptions, for: OpenAIProvider.namespace)
            request.providerOptions = options
        }
        return request
    }
}

/// A Gateway embedding model backed by the OpenAI-compatible API.
public struct GatewayEmbeddingModel: EmbeddingModel, Sendable {
    /// The routed model identifier.
    public let id: String

    /// Capability metadata for the model.
    public let capabilities: ModelCapabilities

    private let underlying: OpenAIEmbeddingModel

    fileprivate init(id: String, underlying: OpenAIEmbeddingModel) {
        self.id = id
        self.capabilities = underlying.capabilities
        self.underlying = underlying
    }

    public func embed(request: EmbeddingRequest) async throws -> EmbeddingResponse {
        var request = request
        if let gatewayOptions = request.providerOptions.options(for: GatewayProvider.namespace) {
            var options = request.providerOptions
            options.set(gatewayOptions, for: OpenAIProvider.namespace)
            request.providerOptions = options
        }
        return try await underlying.embed(request: request)
    }
}

/// A Gateway image model backed by the OpenAI-compatible API.
public struct GatewayImageModel: ImageModel, Sendable {
    /// The routed model identifier.
    public let id: String

    /// Capability metadata for the model.
    public let capabilities: ModelCapabilities

    private let underlying: OpenAIImageModel

    fileprivate init(id: String, underlying: OpenAIImageModel) {
        self.id = id
        self.capabilities = underlying.capabilities
        self.underlying = underlying
    }

    public func generateImage(request: ImageGenerationRequest) async throws -> ImageGenerationResponse {
        var request = request
        if let gatewayOptions = request.providerOptions.options(for: GatewayProvider.namespace) {
            var options = request.providerOptions
            options.set(gatewayOptions, for: OpenAIProvider.namespace)
            request.providerOptions = options
        }
        return try await underlying.generateImage(request: request)
    }
}
