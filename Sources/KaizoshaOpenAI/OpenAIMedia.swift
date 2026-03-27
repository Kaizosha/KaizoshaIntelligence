import Foundation
import KaizoshaProvider
import KaizoshaTransport

/// Supported file purposes for the OpenAI Files API.
public enum OpenAIFilePurpose: String, Sendable, Hashable {
    case assistants
    case batch
    case fineTune = "fine-tune"
    case userData = "user_data"
    case evals
}

/// A file upload request for the OpenAI Files API.
public struct OpenAIFileUploadRequest: Sendable, Hashable {
    /// The file bytes to upload.
    public var data: Data

    /// The file name to report to OpenAI.
    public var fileName: String

    /// The MIME type for the uploaded file.
    public var mimeType: String

    /// The file purpose used by OpenAI.
    public var purpose: OpenAIFilePurpose

    /// Creates a file upload request.
    public init(
        data: Data,
        fileName: String,
        mimeType: String = "application/octet-stream",
        purpose: OpenAIFilePurpose = .assistants
    ) {
        self.data = data
        self.fileName = fileName
        self.mimeType = mimeType
        self.purpose = purpose
    }
}

/// A file descriptor returned by the OpenAI Files API.
public struct OpenAIFile: Sendable, Hashable {
    /// The file identifier.
    public var id: String

    /// The file name.
    public var fileName: String

    /// The file size in bytes.
    public var bytes: Int?

    /// The file purpose.
    public var purpose: String?

    /// The creation timestamp.
    public var createdAt: Date?

    /// The expiration timestamp when present.
    public var expiresAt: Date?

    /// The full raw payload returned by OpenAI.
    public var rawPayload: JSONValue

    /// Creates a file descriptor.
    public init(
        id: String,
        fileName: String,
        bytes: Int? = nil,
        purpose: String? = nil,
        createdAt: Date? = nil,
        expiresAt: Date? = nil,
        rawPayload: JSONValue
    ) {
        self.id = id
        self.fileName = fileName
        self.bytes = bytes
        self.purpose = purpose
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.rawPayload = rawPayload
    }
}

/// Output background options for OpenAI GPT image models.
public enum OpenAIImageBackground: String, Sendable, Hashable {
    case auto
    case opaque
    case transparent
}

/// Output format options for OpenAI GPT image models.
public enum OpenAIImageOutputFormat: String, Sendable, Hashable {
    case png
    case jpeg
    case webp
}

/// Quality options for OpenAI GPT image models.
public enum OpenAIImageQuality: String, Sendable, Hashable {
    case auto
    case low
    case medium
    case high
}

/// A request to edit one or more images with OpenAI image models.
public struct OpenAIImageEditRequest: Sendable, Hashable {
    /// The edit prompt.
    public var prompt: String

    /// The source images to edit.
    public var images: [Data]

    /// The optional mask image.
    public var mask: Data?

    /// The MIME type shared by the source images.
    public var mimeType: String

    /// The requested output size.
    public var size: String?

    /// The number of edited images to generate.
    public var count: Int

    /// The requested output format.
    public var outputFormat: OpenAIImageOutputFormat?

    /// The requested output background.
    public var background: OpenAIImageBackground?

    /// The requested output quality.
    public var quality: OpenAIImageQuality?

    /// The number of partial images to request when streaming.
    public var partialImages: Int?

    /// Additional provider options.
    public var providerOptions: ProviderOptions

    /// Request metadata.
    public var metadata: [String: String]

    /// Creates an image edit request.
    public init(
        prompt: String,
        images: [Data],
        mask: Data? = nil,
        mimeType: String = "image/png",
        size: String? = nil,
        count: Int = 1,
        outputFormat: OpenAIImageOutputFormat? = nil,
        background: OpenAIImageBackground? = nil,
        quality: OpenAIImageQuality? = nil,
        partialImages: Int? = nil,
        providerOptions: ProviderOptions = ProviderOptions(),
        metadata: [String: String] = [:]
    ) {
        self.prompt = prompt
        self.images = images
        self.mask = mask
        self.mimeType = mimeType
        self.size = size
        self.count = count
        self.outputFormat = outputFormat
        self.background = background
        self.quality = quality
        self.partialImages = partialImages
        self.providerOptions = providerOptions
        self.metadata = metadata
    }
}

/// A request to create image variations with OpenAI image models.
public struct OpenAIImageVariationRequest: Sendable, Hashable {
    /// The source image to vary.
    public var image: Data

    /// The source image MIME type.
    public var mimeType: String

    /// The requested output size.
    public var size: String?

    /// The number of variations to generate.
    public var count: Int

    /// Additional provider options.
    public var providerOptions: ProviderOptions

    /// Request metadata.
    public var metadata: [String: String]

    /// Creates an image variation request.
    public init(
        image: Data,
        mimeType: String = "image/png",
        size: String? = nil,
        count: Int = 1,
        providerOptions: ProviderOptions = ProviderOptions(),
        metadata: [String: String] = [:]
    ) {
        self.image = image
        self.mimeType = mimeType
        self.size = size
        self.count = count
        self.providerOptions = providerOptions
        self.metadata = metadata
    }
}

/// Streaming events emitted by OpenAI image generation endpoints.
public enum OpenAIImageGenerationStreamEvent: Sendable {
    case status(String)
    case partialImage(GeneratedImage)
    case completed(ImageGenerationResponse)
    case raw(type: String, payload: JSONValue)
}

/// Supported transcription response formats for OpenAI speech-to-text APIs.
public enum OpenAITranscriptionResponseFormat: String, Sendable, Hashable {
    case json
    case text
    case srt
    case verboseJSON = "verbose_json"
    case vtt
    case diarizedJSON = "diarized_json"
}

/// Structured chunking strategies for OpenAI transcription requests.
public enum OpenAITranscriptionChunkingStrategy: Sendable, Hashable {
    case auto
    case serverVAD(OpenAITranscriptionServerVADChunking)

    var multipartValue: String {
        switch self {
        case .auto:
            return "auto"
        case .serverVAD:
            return "server_vad"
        }
    }

    var extraFields: [(String, String)] {
        switch self {
        case .auto:
            return []
        case .serverVAD(let configuration):
            return configuration.multipartFields
        }
    }
}

/// Server-VAD chunking options for transcription requests.
public struct OpenAITranscriptionServerVADChunking: Sendable, Hashable {
    /// The optional VAD threshold.
    public var threshold: Double?

    /// The optional prefix padding in milliseconds.
    public var prefixPaddingMilliseconds: Int?

    /// The optional silence duration in milliseconds.
    public var silenceDurationMilliseconds: Int?

    /// Creates server-VAD chunking options.
    public init(
        threshold: Double? = nil,
        prefixPaddingMilliseconds: Int? = nil,
        silenceDurationMilliseconds: Int? = nil
    ) {
        self.threshold = threshold
        self.prefixPaddingMilliseconds = prefixPaddingMilliseconds
        self.silenceDurationMilliseconds = silenceDurationMilliseconds
    }

    var multipartFields: [(String, String)] {
        var fields: [(String, String)] = []
        if let threshold {
            fields.append(("chunking_strategy[threshold]", String(threshold)))
        }
        if let prefixPaddingMilliseconds {
            fields.append(("chunking_strategy[prefix_padding_ms]", String(prefixPaddingMilliseconds)))
        }
        if let silenceDurationMilliseconds {
            fields.append(("chunking_strategy[silence_duration_ms]", String(silenceDurationMilliseconds)))
        }
        return fields
    }
}

/// A known speaker reference for diarized transcription requests.
public struct OpenAITranscriptionKnownSpeaker: Sendable, Hashable {
    /// The short speaker label.
    public var name: String

    /// The speaker reference clip encoded as a data URL.
    public var referenceDataURL: String

    /// Creates a known speaker reference.
    public init(name: String, referenceDataURL: String) {
        self.name = name
        self.referenceDataURL = referenceDataURL
    }
}

/// Extended transcription options for OpenAI speech-to-text APIs.
public struct OpenAITranscriptionOptions: Sendable, Hashable {
    /// The response format to request.
    public var responseFormat: OpenAITranscriptionResponseFormat

    /// Whether to request log probabilities when supported.
    public var includeLogprobs: Bool

    /// Requested timestamp granularities.
    public var timestampGranularities: [String]

    /// The legacy raw chunking strategy for long recordings.
    public var chunkingStrategy: String?

    /// Structured chunking controls for long recordings.
    public var chunking: OpenAITranscriptionChunkingStrategy?

    /// Known speaker references for diarized transcription.
    public var knownSpeakers: [OpenAITranscriptionKnownSpeaker]

    /// Creates OpenAI transcription options.
    public init(
        responseFormat: OpenAITranscriptionResponseFormat = .json,
        includeLogprobs: Bool = false,
        timestampGranularities: [String] = [],
        chunkingStrategy: String? = nil,
        chunking: OpenAITranscriptionChunkingStrategy? = nil,
        knownSpeakers: [OpenAITranscriptionKnownSpeaker] = []
    ) {
        self.responseFormat = responseFormat
        self.includeLogprobs = includeLogprobs
        self.timestampGranularities = timestampGranularities
        self.chunkingStrategy = chunkingStrategy
        self.chunking = chunking
        self.knownSpeakers = knownSpeakers
    }
}

/// A detailed transcription segment returned by OpenAI.
public struct OpenAITranscriptionSegment: Sendable, Hashable {
    /// The segment identifier.
    public var id: String?

    /// The segment start time in seconds.
    public var startTime: Double

    /// The segment end time in seconds.
    public var endTime: Double

    /// The transcribed text.
    public var text: String

    /// The resolved speaker label when available.
    public var speaker: String?

    /// Creates a detailed transcription segment.
    public init(
        id: String? = nil,
        startTime: Double,
        endTime: Double,
        text: String,
        speaker: String? = nil
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
        self.speaker = speaker
    }
}

/// A detailed OpenAI transcription or translation result.
public struct OpenAITranscriptionResult: Sendable, Hashable {
    /// The model identifier.
    public var modelID: String

    /// The transcribed or translated text.
    public var text: String

    /// Parsed segment metadata.
    public var segments: [OpenAITranscriptionSegment]

    /// Token or duration usage metadata when available.
    public var usage: Usage?

    /// The raw payload returned by OpenAI.
    public var rawPayload: JSONValue

    /// Creates a detailed transcription result.
    public init(
        modelID: String,
        text: String,
        segments: [OpenAITranscriptionSegment] = [],
        usage: Usage? = nil,
        rawPayload: JSONValue
    ) {
        self.modelID = modelID
        self.text = text
        self.segments = segments
        self.usage = usage
        self.rawPayload = rawPayload
    }
}

/// Streaming events emitted by OpenAI transcription endpoints.
public enum OpenAITranscriptionStreamEvent: Sendable {
    case status(String)
    case textDelta(String)
    case segment(OpenAITranscriptionSegment)
    case completed(OpenAITranscriptionResult)
    case raw(type: String, payload: JSONValue)
}

/// A request to translate audio using OpenAI.
public struct OpenAITranslationRequest: Sendable, Hashable {
    /// The audio bytes to translate.
    public var audio: Data

    /// The original file name.
    public var fileName: String

    /// The audio MIME type.
    public var mimeType: String

    /// Optional prompt context.
    public var prompt: String?

    /// Extended OpenAI transcription options.
    public var options: OpenAITranscriptionOptions

    /// Additional provider options.
    public var providerOptions: ProviderOptions

    /// Request metadata.
    public var metadata: [String: String]

    /// Creates a translation request.
    public init(
        audio: Data,
        fileName: String,
        mimeType: String = "audio/wav",
        prompt: String? = nil,
        options: OpenAITranscriptionOptions = OpenAITranscriptionOptions(),
        providerOptions: ProviderOptions = ProviderOptions(),
        metadata: [String: String] = [:]
    ) {
        self.audio = audio
        self.fileName = fileName
        self.mimeType = mimeType
        self.prompt = prompt
        self.options = options
        self.providerOptions = providerOptions
        self.metadata = metadata
    }
}

/// Streaming events emitted by OpenAI text-to-speech APIs.
public enum OpenAISpeechStreamEvent: Sendable {
    case status(String)
    case audioChunk(Data, mimeType: String)
    case completed(SpeechGenerationResponse)
    case raw(type: String, payload: JSONValue)
}

/// A request to create a custom voice in OpenAI.
public struct OpenAICustomVoiceRequest: Sendable, Hashable {
    /// The voice display name.
    public var name: String

    /// The previously uploaded consent identifier.
    public var consentID: String

    /// The reference audio sample.
    public var audioSample: Data

    /// The MIME type for the audio sample.
    public var mimeType: String

    /// Creates a custom voice request.
    public init(
        name: String,
        consentID: String,
        audioSample: Data,
        mimeType: String = "audio/wav"
    ) {
        self.name = name
        self.consentID = consentID
        self.audioSample = audioSample
        self.mimeType = mimeType
    }
}

/// A custom voice returned by OpenAI.
public struct OpenAIVoice: Sendable, Hashable {
    /// The voice identifier.
    public var id: String

    /// The voice display name.
    public var name: String

    /// The raw payload returned by OpenAI.
    public var rawPayload: JSONValue

    /// Creates a custom voice descriptor.
    public init(id: String, name: String, rawPayload: JSONValue) {
        self.id = id
        self.name = name
        self.rawPayload = rawPayload
    }
}

public extension OpenAIProvider {
    /// Uploads a file for later use with OpenAI APIs.
    func uploadFile(_ request: OpenAIFileUploadRequest) async throws -> OpenAIFile {
        var multipart = MultipartFormData()
        multipart.addText(name: "purpose", value: request.purpose.rawValue)
        multipart.addData(name: "file", fileName: request.fileName, mimeType: request.mimeType, data: request.data)

        let response = try await client.send(
            HTTPRequest(
                url: baseURL.appendingPathComponents("files"),
                headers: [
                    "Authorization": "Bearer \(apiKey)",
                    "Content-Type": multipart.contentType,
                ],
                body: multipart.data()
            )
        )

        guard (200..<300).contains(response.statusCode) else {
            throw KaizoshaError.httpFailure(
                statusCode: response.statusCode,
                body: String(decoding: response.body, as: UTF8.self)
            )
        }

        return try OpenAIFile(payload: JSONValue.decode(response.body))
    }

    /// Retrieves metadata for a previously uploaded file.
    func retrieveFile(_ id: String) async throws -> OpenAIFile {
        let payload = try await client.sendJSON(
            HTTPRequest(
                url: baseURL.appendingPathComponents("files/\(id)"),
                method: .get,
                headers: authorizationHeaders
            )
        )

        return try OpenAIFile(payload: payload)
    }
}

public extension OpenAIImageModel {
    /// Edits one or more images.
    func editImage(request: OpenAIImageEditRequest) async throws -> ImageGenerationResponse {
        try CapabilityValidator.validate(ImageGenerationRequest(prompt: request.prompt, count: request.count), for: self)
        let response = try await client.send(
            HTTPRequest(
                url: baseURL.appendingPathComponents("images/edits"),
                headers: [
                    "Authorization": "Bearer \(apiKey)",
                    "Content-Type": "application/json",
                ],
                body: try imageEditPayload(for: request, stream: false).data()
            )
        )

        guard (200..<300).contains(response.statusCode) else {
            throw KaizoshaError.httpFailure(
                statusCode: response.statusCode,
                body: String(decoding: response.body, as: UTF8.self)
            )
        }

        return try Self.parseImageResponse(JSONValue.decode(response.body), modelID: id)
    }

    /// Creates image variations.
    func varyImage(request: OpenAIImageVariationRequest) async throws -> ImageGenerationResponse {
        try CapabilityValidator.validate(ImageGenerationRequest(prompt: "variation", count: request.count), for: self)
        guard OpenAIRequestSupport.supportsImageVariations(modelID: id) else {
            throw KaizoshaError.unsupportedCapability(modelID: id, capability: "OpenAI image variations")
        }

        var multipart = MultipartFormData()
        multipart.addText(name: "model", value: id)
        multipart.addData(name: "image", fileName: "variation-input", mimeType: request.mimeType, data: request.image)
        multipart.addText(name: "n", value: String(request.count))
        if let size = request.size {
            multipart.addText(name: "size", value: size)
        }

        let response = try await client.send(
            HTTPRequest(
                url: baseURL.appendingPathComponents("images/variations"),
                headers: [
                    "Authorization": "Bearer \(apiKey)",
                    "Content-Type": multipart.contentType,
                ],
                body: multipart.data()
            )
        )

        guard (200..<300).contains(response.statusCode) else {
            throw KaizoshaError.httpFailure(
                statusCode: response.statusCode,
                body: String(decoding: response.body, as: UTF8.self)
            )
        }

        return try Self.parseImageResponse(JSONValue.decode(response.body), modelID: id)
    }

    /// Streams image generation results from GPT image models.
    func streamGeneratedImages(request: ImageGenerationRequest, partialImages: Int = 2) -> AsyncThrowingStream<OpenAIImageGenerationStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    continuation.yield(.status("started"))
                    var object: [String: JSONValue] = [
                        "model": .string(id),
                        "prompt": .string(request.prompt),
                        "n": .number(Double(request.count)),
                        "stream": .bool(true),
                        "partial_images": .number(Double(max(0, min(3, partialImages)))),
                    ]
                    if let size = request.size {
                        object["size"] = .string(size)
                    }

                    let body = JSONValue.object(object).mergingObject(with: request.providerOptions.options(for: OpenAIProvider.namespace))
                    let events = await client.streamEvents(
                        HTTPRequest(
                            url: baseURL.appendingPathComponents("images/generations"),
                            headers: [
                                "Authorization": "Bearer \(apiKey)",
                                "Content-Type": "application/json",
                            ],
                            body: try body.data()
                        )
                    )

                    var completed: ImageGenerationResponse?

                    for try await event in events {
                        guard event.data.isEmpty == false else { continue }
                        let payload = try JSONValue.decode(Data(event.data.utf8))
                        if let image = Self.parsePartialImage(from: payload) {
                            continuation.yield(.partialImage(image))
                        }

                        if let response = try? Self.parseImageResponse(payload, modelID: id) {
                            completed = response
                        }

                        continuation.yield(.raw(type: event.event ?? "message", payload: payload))
                    }

                    if let completed {
                        continuation.yield(.completed(completed))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private func imageEditPayload(for request: OpenAIImageEditRequest, stream: Bool) -> JSONValue {
        var object: [String: JSONValue] = [
            "model": .string(id),
            "prompt": .string(request.prompt),
            "images": .array(request.images.map { image in
                .object([
                    "image_url": .string("data:\(request.mimeType);base64,\(image.base64EncodedString())"),
                ])
            }),
            "n": .number(Double(request.count)),
        ]

        if let mask = request.mask {
            object["mask"] = .string("data:\(request.mimeType);base64,\(mask.base64EncodedString())")
        }
        if let size = request.size {
            object["size"] = .string(size)
        }
        if let outputFormat = request.outputFormat {
            object["output_format"] = .string(outputFormat.rawValue)
        }
        if let background = request.background {
            object["background"] = .string(background.rawValue)
        }
        if let quality = request.quality {
            object["quality"] = .string(quality.rawValue)
        }
        if stream {
            object["stream"] = .bool(true)
            if let partialImages = request.partialImages {
                object["partial_images"] = .number(Double(max(0, min(3, partialImages))))
            }
        }

        return JSONValue.object(object).mergingObject(with: request.providerOptions.options(for: OpenAIProvider.namespace))
    }

    private static func parseImageResponse(_ payload: JSONValue, modelID: String) throws -> ImageGenerationResponse {
        guard let items = payload.objectValue?["data"]?.arrayValue else {
            throw KaizoshaError.invalidResponse("OpenAI returned an invalid image payload.")
        }

        let images = items.compactMap { item -> GeneratedImage? in
            guard let object = item.objectValue else { return nil }
            if let base64 = object["b64_json"]?.stringValue,
               let bytes = Data(base64Encoded: base64) {
                return GeneratedImage(
                    data: bytes,
                    mimeType: OpenAIRequestSupport.inferImageMimeType(from: bytes),
                    revisedPrompt: object["revised_prompt"]?.stringValue
                )
            }

            if let base64 = object["partial_image_b64"]?.stringValue,
               let bytes = Data(base64Encoded: base64) {
                return GeneratedImage(
                    data: bytes,
                    mimeType: OpenAIRequestSupport.inferImageMimeType(from: bytes),
                    revisedPrompt: object["revised_prompt"]?.stringValue
                )
            }

            return nil
        }

        return ImageGenerationResponse(modelID: modelID, images: images)
    }

    private static func parsePartialImage(from payload: JSONValue) -> GeneratedImage? {
        let images = try? parseImageResponse(payload, modelID: "stream")
        return images?.images.first
    }
}

public extension OpenAISpeechModel {
    /// Supported built-in voices documented by OpenAI.
    static let builtInVoices = [
        "alloy", "ash", "ballad", "coral", "echo", "fable", "nova",
        "onyx", "sage", "shimmer", "verse", "marin", "cedar",
    ]

    /// Streams synthesized audio as server-sent events.
    func streamSpeech(
        request: SpeechGenerationRequest,
        instructions: String? = nil,
        speed: Double? = nil
    ) -> AsyncThrowingStream<OpenAISpeechStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    if OpenAIRequestSupport.supportsSpeechStreaming(modelID: id) == false {
                        throw KaizoshaError.unsupportedCapability(modelID: id, capability: "streamed speech")
                    }

                    if instructions != nil, OpenAIRequestSupport.supportsSpeechInstructions(modelID: id) == false {
                        throw KaizoshaError.unsupportedCapability(modelID: id, capability: "speech instructions")
                    }

                    continuation.yield(.status("started"))

                    var object: [String: JSONValue] = [
                        "model": .string(id),
                        "input": .string(request.prompt),
                        "voice": .string(request.voice),
                        "response_format": .string(Self.responseFormat(for: request.format)),
                        "stream_format": .string("sse"),
                    ]
                    if let instructions {
                        object["instructions"] = .string(instructions)
                    }
                    if let speed {
                        object["speed"] = .number(speed)
                    }

                    let body = JSONValue.object(object).mergingObject(with: request.providerOptions.options(for: OpenAIProvider.namespace))
                    let events = await client.streamEvents(
                        HTTPRequest(
                            url: baseURL.appendingPathComponents("audio/speech"),
                            headers: [
                                "Authorization": "Bearer \(apiKey)",
                                "Content-Type": "application/json",
                            ],
                            body: try body.data()
                        )
                    )

                    var collected = Data()
                    let mimeType = Self.mimeType(for: request.format)

                    for try await event in events {
                        guard event.data.isEmpty == false else { continue }
                        let payload = try JSONValue.decode(Data(event.data.utf8))
                        if let chunk = Self.parseAudioChunk(from: payload) {
                            collected.append(chunk)
                            continuation.yield(.audioChunk(chunk, mimeType: mimeType))
                        }
                        continuation.yield(.raw(type: event.event ?? "message", payload: payload))
                    }

                    continuation.yield(.completed(SpeechGenerationResponse(modelID: id, audio: collected, mimeType: mimeType)))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// Creates a reusable custom voice.
    func createVoice(_ request: OpenAICustomVoiceRequest) async throws -> OpenAIVoice {
        var multipart = MultipartFormData()
        multipart.addText(name: "name", value: request.name)
        multipart.addText(name: "consent", value: request.consentID)
        multipart.addData(name: "audio_sample", fileName: "sample", mimeType: request.mimeType, data: request.audioSample)

        let response = try await client.send(
            HTTPRequest(
                url: baseURL.appendingPathComponents("audio/voices"),
                headers: [
                    "Authorization": "Bearer \(apiKey)",
                    "Content-Type": multipart.contentType,
                ],
                body: multipart.data()
            )
        )

        guard (200..<300).contains(response.statusCode) else {
            throw KaizoshaError.httpFailure(
                statusCode: response.statusCode,
                body: String(decoding: response.body, as: UTF8.self)
            )
        }

        let payload = try JSONValue.decode(response.body)
        guard let object = payload.objectValue,
              let id = object["id"]?.stringValue else {
            throw KaizoshaError.invalidResponse("OpenAI returned an invalid voice payload.")
        }

        return OpenAIVoice(id: id, name: object["name"]?.stringValue ?? request.name, rawPayload: payload)
    }

    private static func responseFormat(for format: AudioFormat) -> String {
        switch format {
        case .pcm16:
            return "pcm"
        case .mp3, .wav, .aac, .flac, .opus:
            return format.rawValue
        }
    }

    private static func mimeType(for format: AudioFormat) -> String {
        switch format {
        case .mp3:
            return "audio/mpeg"
        case .wav:
            return "audio/wav"
        case .aac:
            return "audio/aac"
        case .flac:
            return "audio/flac"
        case .opus:
            return "audio/ogg"
        case .pcm16:
            return "audio/pcm"
        }
    }

    private static func parseAudioChunk(from payload: JSONValue) -> Data? {
        let object = payload.objectValue
        let base64 = object?["audio"]?.stringValue
            ?? object?["delta"]?.stringValue
            ?? object?["data"]?.stringValue
        guard let base64 else { return nil }
        return Data(base64Encoded: base64)
    }
}

public extension OpenAITranscriptionModel {
    /// Transcribes audio and preserves detailed OpenAI metadata.
    func transcribeDetailed(
        request: TranscriptionRequest,
        options: OpenAITranscriptionOptions = OpenAITranscriptionOptions()
    ) async throws -> OpenAITranscriptionResult {
        try validateTranscriptionOptions(options, prompt: request.prompt, streaming: false)
        let response = try await sendSpeechToTextRequest(
            path: "audio/transcriptions",
            audio: request.audio,
            fileName: request.fileName,
            mimeType: request.mimeType,
            prompt: request.prompt,
            language: request.language,
            options: options,
            providerOptions: request.providerOptions
        )
        return try Self.parseTranscriptionResult(payload: response, modelID: id)
    }

    /// Streams transcription events for a completed audio recording.
    func streamTranscription(
        request: TranscriptionRequest,
        options: OpenAITranscriptionOptions = OpenAITranscriptionOptions()
    ) -> AsyncThrowingStream<OpenAITranscriptionStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try validateTranscriptionOptions(options, prompt: request.prompt, streaming: true)
                    continuation.yield(.status("started"))
                    var multipart = MultipartFormData()
                    multipart.addText(name: "model", value: id)
                    multipart.addData(name: "file", fileName: request.fileName, mimeType: request.mimeType, data: request.audio)
                    multipart.addText(name: "stream", value: "true")
                    if let prompt = request.prompt {
                        multipart.addText(name: "prompt", value: prompt)
                    }
                    if let language = request.language {
                        multipart.addText(name: "language", value: language)
                    }
                    Self.apply(options: options, to: &multipart)

                    let events = await client.streamEvents(
                        HTTPRequest(
                            url: baseURL.appendingPathComponents("audio/transcriptions"),
                            headers: [
                                "Authorization": "Bearer \(apiKey)",
                                "Content-Type": multipart.contentType,
                            ],
                            body: multipart.data()
                        )
                    )

                    var collectedText = ""
                    var collectedSegments: [OpenAITranscriptionSegment] = []
                    var usage: Usage?

                    for try await event in events {
                        guard event.data.isEmpty == false else { continue }
                        let payload = try JSONValue.decode(Data(event.data.utf8))
                        let type = payload.objectValue?["type"]?.stringValue ?? event.event ?? "message"

                        switch type {
                        case "transcript.text.delta":
                            let delta = payload.objectValue?["delta"]?.stringValue ?? ""
                            collectedText += delta
                            continuation.yield(.textDelta(delta))
                        case "transcript.text.segment":
                            if let segment = Self.parseSegment(payload.objectValue ?? [:]) {
                                collectedSegments.append(segment)
                                continuation.yield(.segment(segment))
                            }
                        case "transcript.text.done":
                            let finalText = payload.objectValue?["text"]?.stringValue ?? collectedText
                            usage = OpenAIRequestSupport.parseUsage(from: payload.objectValue?["usage"]?.objectValue) ?? usage
                            continuation.yield(
                                .completed(
                                    OpenAITranscriptionResult(
                                        modelID: id,
                                        text: finalText,
                                        segments: collectedSegments,
                                        usage: usage,
                                        rawPayload: payload
                                    )
                                )
                            )
                        default:
                            continuation.yield(.raw(type: type, payload: payload))
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// Translates audio to English.
    func translate(_ request: OpenAITranslationRequest) async throws -> OpenAITranscriptionResult {
        let payload = try await sendSpeechToTextRequest(
            path: "audio/translations",
            audio: request.audio,
            fileName: request.fileName,
            mimeType: request.mimeType,
            prompt: request.prompt,
            language: nil,
            options: request.options,
            providerOptions: request.providerOptions
        )
        return try Self.parseTranscriptionResult(payload: payload, modelID: id)
    }

    private func sendSpeechToTextRequest(
        path: String,
        audio: Data,
        fileName: String,
        mimeType: String,
        prompt: String?,
        language: String?,
        options: OpenAITranscriptionOptions,
        providerOptions: ProviderOptions
    ) async throws -> JSONValue {
        var multipart = MultipartFormData()
        multipart.addText(name: "model", value: id)
        multipart.addData(name: "file", fileName: fileName, mimeType: mimeType, data: audio)
        if let prompt {
            multipart.addText(name: "prompt", value: prompt)
        }
        if let language {
            multipart.addText(name: "language", value: language)
        }
        Self.apply(options: options, to: &multipart)
        Self.applyProviderOptions(providerOptions.options(for: OpenAIProvider.namespace), to: &multipart)

        let response = try await client.send(
            HTTPRequest(
                url: baseURL.appendingPathComponents(path),
                headers: [
                    "Authorization": "Bearer \(apiKey)",
                    "Content-Type": multipart.contentType,
                ],
                body: multipart.data()
            )
        )

        guard (200..<300).contains(response.statusCode) else {
            throw KaizoshaError.httpFailure(
                statusCode: response.statusCode,
                body: String(decoding: response.body, as: UTF8.self)
            )
        }

        if [.json, .verboseJSON, .diarizedJSON].contains(options.responseFormat) {
            return try JSONValue.decode(response.body)
        }

        let text = String(decoding: response.body, as: UTF8.self)
        return .object([
            "text": .string(text),
            "response_format": .string(options.responseFormat.rawValue),
        ])
    }

    private static func apply(options: OpenAITranscriptionOptions, to multipart: inout MultipartFormData) {
        multipart.addText(name: "response_format", value: options.responseFormat.rawValue)
        if options.includeLogprobs {
            multipart.addText(name: "include[]", value: "logprobs")
        }
        for granularity in options.timestampGranularities {
            multipart.addText(name: "timestamp_granularities[]", value: granularity)
        }
        if let chunking = options.chunking {
            multipart.addText(name: "chunking_strategy", value: chunking.multipartValue)
            for (name, value) in chunking.extraFields {
                multipart.addText(name: name, value: value)
            }
        } else if let chunkingStrategy = options.chunkingStrategy {
            multipart.addText(name: "chunking_strategy", value: chunkingStrategy)
        }
        for speaker in options.knownSpeakers {
            multipart.addText(name: "known_speaker_names[]", value: speaker.name)
            multipart.addText(name: "known_speaker_references[]", value: speaker.referenceDataURL)
        }
    }

    private static func applyProviderOptions(_ value: JSONValue?, to multipart: inout MultipartFormData) {
        guard let object = value?.objectValue else { return }
        if let include = object["include"]?.arrayValue?.compactMap(\.stringValue) {
            for entry in include {
                multipart.addText(name: "include[]", value: entry)
            }
        }
    }

    private static func parseTranscriptionResult(payload: JSONValue, modelID: String) throws -> OpenAITranscriptionResult {
        guard let object = payload.objectValue else {
            throw KaizoshaError.invalidResponse("OpenAI returned an invalid transcription payload.")
        }

        let text = object["text"]?.stringValue ?? ""
        let segments = (object["segments"]?.arrayValue ?? []).compactMap { entry in
            parseSegment(entry.objectValue ?? [:])
        }
        let usage = OpenAIRequestSupport.parseUsage(from: object["usage"]?.objectValue)

        return OpenAITranscriptionResult(
            modelID: modelID,
            text: text,
            segments: segments,
            usage: usage,
            rawPayload: payload
        )
    }

    private static func parseSegment(_ object: [String: JSONValue]) -> OpenAITranscriptionSegment? {
        guard let start = object["start"]?.numberValue,
              let end = object["end"]?.numberValue,
              let text = object["text"]?.stringValue else {
            return nil
        }

        return OpenAITranscriptionSegment(
            id: object["id"]?.stringValue ?? object["segment_id"]?.stringValue,
            startTime: start,
            endTime: end,
            text: text,
            speaker: object["speaker"]?.stringValue
        )
    }

    private func validateTranscriptionOptions(
        _ options: OpenAITranscriptionOptions,
        prompt: String?,
        streaming: Bool
    ) throws {
        let supportedFormats = OpenAIRequestSupport.supportedTranscriptionFormats(for: id)
        guard supportedFormats.contains(options.responseFormat) else {
            throw KaizoshaError.unsupportedCapability(
                modelID: id,
                capability: "transcription response format \(options.responseFormat.rawValue)"
            )
        }

        if streaming, OpenAICapabilityResolver.profile(for: id).supportsTranscriptionStreaming == false {
            throw KaizoshaError.unsupportedCapability(modelID: id, capability: "streamed transcription")
        }

        if options.includeLogprobs {
            guard options.responseFormat == .json else {
                throw KaizoshaError.invalidRequest("OpenAI transcription logprobs require the json response format.")
            }
            guard OpenAIRequestSupport.supportsTranscriptionLogprobs(modelID: id) else {
                throw KaizoshaError.unsupportedCapability(modelID: id, capability: "transcription logprobs")
            }
        }

        if options.timestampGranularities.isEmpty == false {
            guard options.responseFormat == .verboseJSON else {
                throw KaizoshaError.invalidRequest("OpenAI timestamp granularities require the verbose_json response format.")
            }
            guard OpenAIRequestSupport.supportsTranscriptionTimestampGranularities(modelID: id) else {
                throw KaizoshaError.unsupportedCapability(modelID: id, capability: "transcription timestamp granularities")
            }
        }

        let isDiarizationModel = OpenAIRequestSupport.isDiarizationModel(id)
        if prompt != nil, OpenAIRequestSupport.supportsTranscriptionPrompt(modelID: id) == false {
            throw KaizoshaError.unsupportedCapability(modelID: id, capability: "transcription prompts")
        }

        if isDiarizationModel {
            if options.responseFormat == .verboseJSON || options.responseFormat == .srt || options.responseFormat == .vtt {
                throw KaizoshaError.unsupportedCapability(
                    modelID: id,
                    capability: "transcription response format \(options.responseFormat.rawValue)"
                )
            }
        } else {
            if options.responseFormat == .diarizedJSON || options.knownSpeakers.isEmpty == false {
                throw KaizoshaError.unsupportedCapability(modelID: id, capability: "speaker diarization")
            }
        }

        if options.knownSpeakers.count > 4 {
            throw KaizoshaError.invalidRequest("OpenAI diarized transcription supports up to four known speaker references.")
        }
    }
}

private extension OpenAIFile {
    init(payload: JSONValue) throws {
        guard let object = payload.objectValue,
              let id = object["id"]?.stringValue else {
            throw KaizoshaError.invalidResponse("OpenAI returned an invalid file payload.")
        }

        self.init(
            id: id,
            fileName: object["filename"]?.stringValue ?? "file",
            bytes: ModelCatalogDecoding.intValue(object["bytes"]),
            purpose: object["purpose"]?.stringValue,
            createdAt: ModelCatalogDecoding.unixTimestamp(object["created_at"]),
            expiresAt: ModelCatalogDecoding.unixTimestamp(object["expires_at"]),
            rawPayload: payload
        )
    }
}
