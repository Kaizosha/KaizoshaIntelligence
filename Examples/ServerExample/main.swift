import Foundation
import KaizoshaGateway
import KaizoshaIntelligence

@main
struct KaizoshaServerExample {
    static func main() async {
        do {
            let provider = try GatewayProvider()
            let response = try await generateText(
                prompt: "Return JSON with keys service and status.",
                using: provider.languageModel("openai/gpt-4o-mini")
            )
            print(response.text)
        } catch {
            fputs("Server example failed: \(error.localizedDescription)\n", stderr)
        }
    }
}
