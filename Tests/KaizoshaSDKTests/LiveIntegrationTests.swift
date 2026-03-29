import Foundation
import KaizoshaAnthropic
import KaizoshaGateway
import KaizoshaGoogle
import KaizoshaIntelligence
import KaizoshaOpenAI
import KaizoshaProvider
import Testing

@Suite("Live Integration")
struct LiveIntegrationTests {
    @Test("OpenAI live text generation")
    func openAILiveTextGeneration() async throws {
        guard ProcessInfo.processInfo.environment["OPENAI_API_KEY"] != nil else { return }
        let provider = try OpenAIProvider()
        let response = try await generateText(
            prompt: "Respond with exactly the word OPENAI.",
            using: provider.languageModel("gpt-4o-mini")
        )
        #expect(response.text.uppercased().contains("OPENAI"))
    }

    @Test("Anthropic live text generation")
    func anthropicLiveTextGeneration() async throws {
        guard ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] != nil else { return }
        let provider = try AnthropicProvider()
        let response = try await generateText(
            prompt: "Respond with exactly the word ANTHROPIC.",
            using: provider.languageModel("claude-3-5-haiku-latest")
        )
        #expect(response.text.uppercased().contains("ANTHROPIC"))
    }

    @Test("Google live text generation")
    func googleLiveTextGeneration() async throws {
        guard ProcessInfo.processInfo.environment["GOOGLE_API_KEY"] != nil else { return }
        let provider = try GoogleProvider()
        let response = try await generateText(
            prompt: "Respond with exactly the word GOOGLE.",
            using: provider.languageModel("gemini-2.0-flash")
        )
        #expect(response.text.uppercased().contains("GOOGLE"))
    }

    @Test("Gateway live text generation")
    func gatewayLiveTextGeneration() async throws {
        guard ProcessInfo.processInfo.environment["AI_GATEWAY_API_KEY"] != nil
                || ProcessInfo.processInfo.environment["VERCEL_OIDC_TOKEN"] != nil else { return }
        let provider = try GatewayProvider()
        let response = try await generateText(
            prompt: "Respond with exactly the word GATEWAY.",
            using: provider.languageModel("openai/gpt-4o-mini")
        )
        #expect(response.text.uppercased().contains("GATEWAY"))
    }

    @Test("OpenAI live provider matrix")
    func openAILiveProviderMatrix() async throws {
        guard ProcessInfo.processInfo.environment["OPENAI_API_KEY"] != nil else { return }
        let provider = try OpenAIProvider()
        try await assertLanguageModelMatrix(
            provider: "OpenAI",
            marker: "OPENAI",
            model: provider.languageModel("gpt-4o-mini")
        )
    }

    @Test("Anthropic live provider matrix")
    func anthropicLiveProviderMatrix() async throws {
        guard ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] != nil else { return }
        let provider = try AnthropicProvider()
        try await assertLanguageModelMatrix(
            provider: "Anthropic",
            marker: "ANTHROPIC",
            model: provider.languageModel("claude-3-5-haiku-latest")
        )
    }

    @Test("Google live provider matrix")
    func googleLiveProviderMatrix() async throws {
        guard ProcessInfo.processInfo.environment["GOOGLE_API_KEY"] != nil else { return }
        let provider = try GoogleProvider()
        try await assertLanguageModelMatrix(
            provider: "Google",
            marker: "GOOGLE",
            model: provider.languageModel("gemini-2.0-flash")
        )
    }
}

private struct LiveProviderMarker: Codable, Sendable {
    let provider: String
}

private struct EchoInput: Codable, Sendable {
    let value: String
}

private struct EchoOutput: Codable, Sendable {
    let echoed: String
}

private func assertLanguageModelMatrix(
    provider: String,
    marker: String,
    model: any LanguageModel
) async throws {
    #expect(model.capabilities.supportsStreaming)
    #expect(model.capabilities.supportsToolCalling)
    #expect(model.capabilities.supportsStructuredOutput)

    let textResponse = try await generateText(
        prompt: "Reply with exactly the token \(marker)_TEXT and no other words.",
        using: model
    )
    #expect(textResponse.text.uppercased().contains("\(marker)_TEXT"))

    var streamedText = ""
    for try await event in streamText(
        prompt: "Reply with exactly the token \(marker)_STREAM and no other words.",
        using: model
    ) {
        if case .textDelta(let delta) = event {
            streamedText += delta
        }
    }
    #expect(streamedText.uppercased().contains("\(marker)_STREAM"))

    let structured = try await generateStructured(
        schema: Schema<LiveProviderMarker>(
            name: "LiveProviderMarker",
            description: "A single provider marker object.",
            jsonSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "provider": .object(["type": .string("string")]),
                ]),
                "required": .array([.string("provider")]),
            ])
        ),
        using: model,
        request: TextGenerationRequest(
            prompt: "Return JSON with exactly one field named provider set to \(marker)."
        )
    )
    #expect(structured.value.provider.uppercased() == marker)

    let echoTool = Tool<EchoInput, EchoOutput>(
        name: "echo_value",
        description: "Echoes back a value for verification.",
        inputSchema: Schema(
            name: "EchoInput",
            description: "The value to echo back.",
            jsonSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "value": .object(["type": .string("string")]),
                ]),
                "required": .array([.string("value")]),
            ])
        ),
        execute: { input, _ in
            EchoOutput(echoed: input.value)
        }
    )

    let toolResponse = try await generateText(
        using: model,
        request: TextGenerationRequest(
            prompt: """
            Call the echo_value tool exactly once with the JSON argument {"value":"\(marker)"}.
            Do not answer directly in plain text before calling the tool.
            """,
            tools: ToolRegistry([echoTool]),
            toolExecution: .manual
        )
    )

    let invocation = try #require(
        toolResponse.toolInvocations.first,
        "\(provider) did not emit a tool invocation in the live matrix test."
    )
    #expect(invocation.name == "echo_value")
    #expect(invocation.input.objectValue?["value"]?.stringValue?.uppercased() == marker)
}
