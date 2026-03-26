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
            writeToStandardError("Server example failed: \(error.localizedDescription)\n")
        }
    }

    private static func writeToStandardError(_ message: String) {
        guard let data = message.data(using: .utf8) else {
            return
        }

        FileHandle.standardError.write(data)
    }
}
