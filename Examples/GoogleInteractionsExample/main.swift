import Foundation
import KaizoshaGoogle

@main
struct KaizoshaGoogleInteractionsExample {
    static func main() async {
        do {
            let provider = try GoogleProvider()
            let interaction = try await provider.interactions.create(
                GoogleInteractionRequest(
                    model: "gemini-3-flash-preview",
                    input: .text("Find one recent Swift concurrency improvement."),
                    tools: [.googleSearch()]
                )
            )

            print(interaction.id ?? "<no id>")
            print(interaction.status ?? "<no status>")
        } catch {
            writeToStandardError("Google interactions example failed: \(error.localizedDescription)\n")
        }
    }

    private static func writeToStandardError(_ message: String) {
        guard let data = message.data(using: .utf8) else { return }
        FileHandle.standardError.write(data)
    }
}
