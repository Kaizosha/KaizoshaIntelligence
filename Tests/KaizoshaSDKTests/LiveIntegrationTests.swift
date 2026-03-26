import Foundation
import KaizoshaAnthropic
import KaizoshaGateway
import KaizoshaGoogle
import KaizoshaIntelligence
import KaizoshaOpenAI
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
}
