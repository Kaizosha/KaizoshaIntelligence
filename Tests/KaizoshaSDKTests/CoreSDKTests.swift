import Foundation
import KaizoshaIntelligence
import KaizoshaProvider
import Testing

@Suite("Core SDK")
struct CoreSDKTests {
    @Test("Structured generation decodes JSON from fenced output")
    func structuredGenerationDecodesJSON() async throws {
        struct Recipe: Codable, Sendable {
            let name: String
        }

        let model = ScriptedLanguageModel(
            responses: [
                TextGenerationResponse(
                    modelID: "stub",
                    message: .assistant("```json\n{\"name\":\"Tea\"}\n```"),
                    text: "```json\n{\"name\":\"Tea\"}\n```",
                    finishReason: .stop
                ),
            ]
        )

        let result = try await generateStructured(
            schema: Schema<Recipe>(
                name: "Recipe",
                description: "A simple recipe object.",
                jsonSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "name": .object(["type": .string("string")]),
                    ]),
                    "required": .array([.string("name")]),
                ])
            ),
            using: model,
            request: TextGenerationRequest(prompt: "Return a recipe.")
        )

        #expect(result.value.name == "Tea")
    }

    @Test("Automatic tool execution performs a single follow-up round")
    func automaticToolExecutionRunsOnce() async throws {
        struct WeatherInput: Codable, Sendable {
            let city: String
        }

        struct WeatherOutput: Codable, Sendable {
            let forecast: String
        }

        let tool = Tool<WeatherInput, WeatherOutput>(
            name: "lookup_weather",
            description: "Returns a weather forecast.",
            inputSchema: Schema(
                name: "WeatherInput",
                description: "The weather lookup payload.",
                jsonSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "city": .object(["type": .string("string")]),
                    ]),
                    "required": .array([.string("city")]),
                ])
            ),
            execute: { input, _ in
                WeatherOutput(forecast: "Sunny in \(input.city)")
            }
        )

        let firstResponse = TextGenerationResponse(
            modelID: "stub",
            message: .assistant(parts: [
                .toolCall(
                    ToolInvocation(
                        id: "call_1",
                        name: "lookup_weather",
                        input: .object(["city": .string("Tokyo")])
                    )
                ),
            ]),
            text: "",
            toolInvocations: [
                ToolInvocation(
                    id: "call_1",
                    name: "lookup_weather",
                    input: .object(["city": .string("Tokyo")])
                ),
            ],
            finishReason: .toolCalls
        )

        let secondResponse = TextGenerationResponse(
            modelID: "stub",
            message: .assistant("Sunny in Tokyo."),
            text: "Sunny in Tokyo.",
            finishReason: .stop
        )

        let model = ScriptedLanguageModel(responses: [firstResponse, secondResponse])
        let response = try await generateText(
            using: model,
            request: TextGenerationRequest(
                prompt: "What's the weather?",
                tools: ToolRegistry([tool]),
                toolExecution: .automaticSingleStep
            )
        )

        #expect(response.text == "Sunny in Tokyo.")
        #expect(response.toolInvocations.count == 1)
        #expect(response.toolResults.count == 1)
        #expect(response.toolResults.first?.isError == false)
    }

    @Test("Automatic tool execution streams tool results and follow-up text")
    func automaticToolExecutionStreamsFollowUp() async throws {
        struct WeatherInput: Codable, Sendable {
            let city: String
        }

        struct WeatherOutput: Codable, Sendable {
            let forecast: String
        }

        let tool = Tool<WeatherInput, WeatherOutput>(
            name: "lookup_weather",
            description: "Returns a weather forecast.",
            inputSchema: Schema(
                name: "WeatherInput",
                description: "The weather lookup payload.",
                jsonSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "city": .object(["type": .string("string")]),
                    ]),
                    "required": .array([.string("city")]),
                ])
            ),
            execute: { input, _ in
                WeatherOutput(forecast: "Sunny in \(input.city)")
            }
        )

        let firstResponse = TextGenerationResponse(
            modelID: "stub",
            message: .assistant(parts: [
                .toolCall(
                    ToolInvocation(
                        id: "call_1",
                        name: "lookup_weather",
                        input: .object(["city": .string("Tokyo")])
                    )
                ),
            ]),
            text: "",
            toolInvocations: [
                ToolInvocation(
                    id: "call_1",
                    name: "lookup_weather",
                    input: .object(["city": .string("Tokyo")])
                ),
            ],
            usage: Usage(inputTokens: 4),
            finishReason: .toolCalls
        )

        let secondResponse = TextGenerationResponse(
            modelID: "stub",
            message: .assistant("Sunny in Tokyo."),
            text: "Sunny in Tokyo.",
            usage: Usage(outputTokens: 6, totalTokens: 10),
            finishReason: .stop
        )

        let model = ScriptedLanguageModel(responses: [firstResponse, secondResponse])
        let stream = streamText(
            using: model,
            request: TextGenerationRequest(
                prompt: "What's the weather?",
                tools: ToolRegistry([tool]),
                toolExecution: .automaticSingleStep
            )
        )

        var streamedText = ""
        var sawToolCall = false
        var streamedToolResults: [ToolResult] = []
        var usageEvents: [Usage] = []

        for try await event in stream {
            switch event {
            case .textDelta(let delta):
                streamedText += delta
            case .toolCall(let invocation):
                sawToolCall = sawToolCall || invocation.name == "lookup_weather"
            case .toolResult(let result):
                streamedToolResults.append(result)
            case .usage(let usage):
                usageEvents.append(usage)
            default:
                break
            }
        }

        #expect(sawToolCall)
        #expect(streamedText == "Sunny in Tokyo.")
        #expect(streamedToolResults.count == 1)
        #expect(streamedToolResults.first?.invocationID == "call_1")
        #expect(usageEvents.map(\.inputTokens).contains(4))
        #expect(usageEvents.map(\.outputTokens).contains(6))
    }
}

private actor ResponseQueue {
    private var responses: [TextGenerationResponse]

    init(_ responses: [TextGenerationResponse]) {
        self.responses = responses
    }

    func next() throws -> TextGenerationResponse {
        guard responses.isEmpty == false else {
            throw KaizoshaError.invalidResponse("No scripted response remains.")
        }
        return responses.removeFirst()
    }
}

private struct ScriptedLanguageModel: LanguageModel, Sendable {
    let id = "scripted"
    let capabilities = ModelCapabilities(
        supportsStreaming: true,
        supportsToolCalling: true,
        supportsStructuredOutput: true
    )

    private let queue: ResponseQueue

    init(responses: [TextGenerationResponse]) {
        self.queue = ResponseQueue(responses)
    }

    func generate(request: TextGenerationRequest) async throws -> TextGenerationResponse {
        try await queue.next()
    }

    func stream(request: TextGenerationRequest) -> AsyncThrowingStream<TextStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let response = try await queue.next()
                    continuation.yield(.status("started"))
                    if response.text.isEmpty == false {
                        continuation.yield(.textDelta(response.text))
                    }
                    for invocation in response.toolInvocations {
                        continuation.yield(.toolCall(invocation))
                    }
                    for result in response.toolResults {
                        continuation.yield(.toolResult(result))
                    }
                    if let usage = response.usage {
                        continuation.yield(.usage(usage))
                    }
                    continuation.yield(.finished(response.finishReason))
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
}
