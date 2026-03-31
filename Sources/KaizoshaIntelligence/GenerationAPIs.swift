import Foundation
import KaizoshaProvider

/// Generates a text response from a language model.
public func generateText(
    using model: any LanguageModel,
    request: TextGenerationRequest
) async throws -> TextGenerationResponse {
    let response = try await model.generate(request: request)
    return try await ToolLoopCoordinator.resolveIfNeeded(
        response: response,
        model: model,
        originalRequest: request
    )
}

/// Generates a text response from a plain-text prompt.
public func generateText(
    prompt: String,
    using model: any LanguageModel,
    generation: GenerationConfig = GenerationConfig(),
    tools: ToolRegistry = ToolRegistry(),
    providerOptions: ProviderOptions = ProviderOptions(),
    metadata: [String: String] = [:],
    toolExecution: ToolExecutionStrategy = .manual
) async throws -> TextGenerationResponse {
    try await generateText(
        using: model,
        request: TextGenerationRequest(
            prompt: prompt,
            generation: generation,
            tools: tools,
            providerOptions: providerOptions,
            metadata: metadata,
            toolExecution: toolExecution
        )
    )
}

/// Streams a text response from a language model.
public func streamText(
    using model: any LanguageModel,
    request: TextGenerationRequest
) -> AsyncThrowingStream<TextStreamEvent, Error> {
    AsyncThrowingStream { continuation in
        let task = Task {
            do {
                let initial = try await ToolLoopCoordinator.collectStream(
                    from: model.stream(request: request),
                    into: continuation,
                    modelID: model.id
                )

                guard request.toolExecution == .automaticSingleStep,
                      initial.toolInvocations.isEmpty == false else {
                    continuation.finish()
                    return
                }

                let toolResults = try await request.tools.execute(
                    invocations: initial.toolInvocations,
                    context: ToolExecutionContext(modelID: model.id, metadata: request.metadata)
                )

                for toolResult in toolResults {
                    continuation.yield(.toolResult(toolResult))
                }

                var followUpRequest = request
                followUpRequest.messages.append(initial.message)
                followUpRequest.messages.append(.tool(toolResults))
                followUpRequest.toolExecution = .manual

                _ = try await ToolLoopCoordinator.collectStream(
                    from: model.stream(request: followUpRequest),
                    into: continuation,
                    modelID: model.id
                )
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

/// Streams a text response from a plain-text prompt.
public func streamText(
    prompt: String,
    using model: any LanguageModel,
    generation: GenerationConfig = GenerationConfig(),
    tools: ToolRegistry = ToolRegistry(),
    providerOptions: ProviderOptions = ProviderOptions(),
    metadata: [String: String] = [:],
    toolExecution: ToolExecutionStrategy = .manual
) -> AsyncThrowingStream<TextStreamEvent, Error> {
    streamText(
        using: model,
        request: TextGenerationRequest(
            prompt: prompt,
            generation: generation,
            tools: tools,
            providerOptions: providerOptions,
            metadata: metadata,
            toolExecution: toolExecution
        )
    )
}

/// Generates a typed structured value from a language model.
public func generateStructured<Value>(
    schema: Schema<Value>,
    using model: any LanguageModel,
    request: TextGenerationRequest
) async throws -> StructuredGenerationResponse<Value> {
    let structuredRequest = StructuredOutputBuilder.apply(schema: schema, to: request)
    let response = try await generateText(using: model, request: structuredRequest)
    let value = try schema.decode(text: response.text)
    return StructuredGenerationResponse(value: value, rawText: response.text, response: response)
}

/// Streams a typed structured value from a language model.
public func streamStructured<Value>(
    schema: Schema<Value>,
    using model: any LanguageModel,
    request: TextGenerationRequest
) -> AsyncThrowingStream<StructuredGenerationEvent<Value>, Error> {
    let structuredRequest = StructuredOutputBuilder.apply(schema: schema, to: request)

    return AsyncThrowingStream { continuation in
        let task = Task {
            do {
                var collectedText = ""

                for try await event in streamText(using: model, request: structuredRequest) {
                    switch event {
                    case .status(let value):
                        continuation.yield(.status(value))
                    case .textDelta(let value):
                        collectedText += value
                        continuation.yield(.textDelta(value))
                    case .toolCall(let invocation):
                        continuation.yield(.toolCall(invocation))
                    case .toolResult(let result):
                        continuation.yield(.toolResult(result))
                    case .usage(let usage):
                        continuation.yield(.usage(usage))
                    case .finished(let reason):
                        let decoded = try schema.decode(text: collectedText)
                        continuation.yield(.value(decoded))
                        continuation.yield(.finished(reason))
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

/// Generates a single embedding.
public func embed(
    _ text: String,
    using model: any EmbeddingModel,
    providerOptions: ProviderOptions = ProviderOptions(),
    metadata: [String: String] = [:]
) async throws -> [Double] {
    let response = try await model.embed(
        request: EmbeddingRequest(
            texts: [text],
            providerOptions: providerOptions,
            metadata: metadata
        )
    )
    guard let embedding = response.embeddings.first else {
        throw KaizoshaError.invalidResponse("The embedding model returned no embeddings.")
    }
    return embedding
}

/// Generates multiple embeddings.
public func embedMany(
    _ texts: [String],
    using model: any EmbeddingModel,
    providerOptions: ProviderOptions = ProviderOptions(),
    metadata: [String: String] = [:]
) async throws -> EmbeddingResponse {
    try await model.embed(
        request: EmbeddingRequest(
            texts: texts,
            providerOptions: providerOptions,
            metadata: metadata
        )
    )
}

/// Generates one or more images.
public func generateImage(
    using model: any ImageModel,
    request: ImageGenerationRequest
) async throws -> ImageGenerationResponse {
    try await model.generateImage(request: request)
}

/// Generates speech audio.
public func generateSpeech(
    using model: any SpeechModel,
    request: SpeechGenerationRequest
) async throws -> SpeechGenerationResponse {
    try await model.generateSpeech(request: request)
}

/// Transcribes audio input.
public func transcribe(
    using model: any TranscriptionModel,
    request: TranscriptionRequest
) async throws -> TranscriptionResponse {
    try await model.transcribe(request: request)
}

private enum StructuredOutputBuilder {
    static func apply<Value>(schema: Schema<Value>, to request: TextGenerationRequest) -> TextGenerationRequest {
        var request = request
        request.messages.insert(
            .system(
                """
                Return only valid JSON matching the following schema.
                Schema name: \(schema.name)
                Description: \(schema.description)
                JSON schema:
                \(String(data: try! schema.jsonSchema.data(prettyPrinted: true), encoding: .utf8) ?? "{}")
                """
            ),
            at: 0
        )
        request.structuredOutput = schema.directive
        return request
    }
}

private enum ToolLoopCoordinator {
    static func resolveIfNeeded(
        response: TextGenerationResponse,
        model: any LanguageModel,
        originalRequest: TextGenerationRequest
    ) async throws -> TextGenerationResponse {
        guard originalRequest.toolExecution == .automaticSingleStep,
              response.toolInvocations.isEmpty == false else {
            return response
        }

        let toolResults = try await originalRequest.tools.execute(
            invocations: response.toolInvocations,
            context: ToolExecutionContext(modelID: model.id, metadata: originalRequest.metadata)
        )

        var followUpRequest = originalRequest
        followUpRequest.messages.append(response.message)
        followUpRequest.messages.append(.tool(toolResults))
        followUpRequest.toolExecution = .manual

        let followUpResponse = try await model.generate(request: followUpRequest)
        return followUpResponse.merging(previous: response, toolResults: toolResults)
    }

    static func collectStream(
        from stream: AsyncThrowingStream<TextStreamEvent, Error>,
        into continuation: AsyncThrowingStream<TextStreamEvent, Error>.Continuation,
        modelID: String
    ) async throws -> TextGenerationResponse {
        var text = ""
        var toolInvocations: [ToolInvocation] = []
        var toolResults: [ToolResult] = []
        var usage: Usage?
        var finishReason: FinishReason = .unknown

        for try await event in stream {
            continuation.yield(event)

            switch event {
            case .status:
                break
            case .textDelta(let value):
                text += value
            case .toolCall(let invocation):
                toolInvocations.append(invocation)
            case .toolResult(let result):
                toolResults.append(result)
            case .usage(let value):
                usage = mergeUsage(usage, with: value)
            case .finished(let value):
                finishReason = value
            }
        }

        let parts = (text.isEmpty ? [] : [MessagePart.text(text)]) + toolInvocations.map(MessagePart.toolCall)
        let assistantMessage = Message(role: .assistant, parts: parts)
        return TextGenerationResponse(
            modelID: modelID,
            message: assistantMessage,
            text: text,
            toolInvocations: toolInvocations,
            toolResults: toolResults,
            usage: usage,
            finishReason: finishReason
        )
    }

    private static func mergeUsage(_ current: Usage?, with update: Usage) -> Usage {
        Usage(
            inputTokens: update.inputTokens ?? current?.inputTokens,
            cacheReadInputTokens: update.cacheReadInputTokens ?? current?.cacheReadInputTokens,
            cacheCreationInputTokens: update.cacheCreationInputTokens ?? current?.cacheCreationInputTokens,
            outputTokens: update.outputTokens ?? current?.outputTokens,
            totalTokens: update.totalTokens ?? current?.totalTokens
        )
    }
}
