import Foundation
import KaizoshaProvider
import KaizoshaTransport

/// A provider factory for Google Gemini-backed models and Google-only services.
public struct GoogleProvider: Sendable {
    /// The provider namespace used in namespaced options.
    public static let namespace = "google"

    private let configuration: GoogleServiceConfiguration

    /// Creates a Google provider.
    public init(
        apiKey: String? = ProcessInfo.processInfo.environment["GOOGLE_API_KEY"],
        baseURL: URL = URL(string: "https://generativelanguage.googleapis.com/v1beta")!,
        previewBaseURL: URL = URL(string: "https://generativelanguage.googleapis.com/v1alpha")!,
        liveWebSocketURL: URL = URL(
            string: "wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent"
        )!,
        transport: (any HTTPTransport)? = nil,
        retryPolicy: RetryPolicy = .default
    ) throws {
        guard let apiKey, apiKey.isEmpty == false else {
            throw KaizoshaError.missingAPIKey(namespace: "GOOGLE_API_KEY")
        }

        let client = HTTPClient(transport: transport, retryPolicy: retryPolicy)
        let catalog = GoogleModelCatalogCache()
        self.configuration = GoogleServiceConfiguration(
            apiKey: apiKey,
            stableBaseURL: baseURL,
            previewBaseURL: previewBaseURL,
            liveSocketURL: liveWebSocketURL,
            client: client,
            catalog: catalog
        )
    }

    /// Creates the provider-neutral Gemini language model handle.
    public func languageModel(_ id: String) -> GoogleLanguageModel {
        GoogleLanguageModel(id: id, configuration: configuration)
    }

    /// Creates the raw Gemini content model handle.
    public func contentModel(_ id: String) -> GoogleContentModel {
        GoogleContentModel(id: id, configuration: configuration)
    }

    /// Creates a Gemini embedding model handle.
    public func embeddingModel(_ id: String) -> GoogleEmbeddingModel {
        GoogleEmbeddingModel(id: id, configuration: configuration)
    }

    /// Creates a Gemini image-capable model handle.
    public func imageModel(_ id: String) -> GoogleImageModel {
        GoogleImageModel(id: id, configuration: configuration)
    }

    /// Access to Google model-catalog operations.
    public var models: GoogleModelsService {
        GoogleModelsService(configuration: configuration)
    }

    /// Access to Google token-count operations.
    public var tokens: GoogleTokensService {
        GoogleTokensService(configuration: configuration)
    }

    /// Access to Google file operations.
    public var files: GoogleFilesService {
        GoogleFilesService(configuration: configuration)
    }

    /// Access to Google generated-file operations.
    public var generatedFiles: GoogleGeneratedFilesService {
        GoogleGeneratedFilesService(configuration: configuration)
    }

    /// Access to Google cached-content operations.
    public var cachedContents: GoogleCachedContentsService {
        GoogleCachedContentsService(configuration: configuration)
    }

    /// Access to Google file-search-store operations.
    public var fileSearchStores: GoogleFileSearchStoresService {
        GoogleFileSearchStoresService(configuration: configuration)
    }

    /// Access to Google batch operations.
    public var batches: GoogleBatchesService {
        GoogleBatchesService(configuration: configuration)
    }

    /// Access to the Google Interactions API.
    public var interactions: GoogleInteractionsService {
        GoogleInteractionsService(configuration: configuration)
    }

    /// Access to Google Live API helpers and websocket clients.
    public var live: GoogleLiveService {
        GoogleLiveService(configuration: configuration)
    }

    /// Fetches the live model catalog from Google.
    public func listModels() async throws -> [AvailableModel] {
        try await models.listAll()
    }
}
