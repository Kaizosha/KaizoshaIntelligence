import Foundation
import KaizoshaIntelligence
import KaizoshaOpenAI

@main
struct KaizoshaCLIExample {
    static func main() async {
        do {
            let provider = try OpenAIProvider()
            let response = try await generateText(
                prompt: "Write a one-line haiku about Swift concurrency.",
                using: provider.languageModel("gpt-4o-mini")
            )
            print(response.text)
        } catch {
            fputs("CLI example failed: \(error.localizedDescription)\n", stderr)
        }
    }
}
