import Foundation
import KaizoshaOpenAI

@main
struct KaizoshaOpenAIResponsesExample {
    static func main() async {
        do {
            let provider = try OpenAIProvider()
            let model = provider.responsesModel("gpt-5")
            let response = try await model.createResponse(
                OpenAIResponseRequest(
                    input: [
                        .system("You explain Swift features clearly."),
                        .user("Summarize actor isolation in one sentence."),
                    ],
                    instructions: "Prefer plain language.",
                    reasoningSummary: .concise,
                    verbosity: .low
                )
            )

            let text = response.output
                .flatMap(\.content)
                .compactMap(\.text)
                .joined(separator: "\n")

            print(text)
        } catch {
            writeToStandardError("OpenAI Responses example failed: \(error.localizedDescription)\n")
        }
    }

    private static func writeToStandardError(_ message: String) {
        guard let data = message.data(using: .utf8) else { return }
        FileHandle.standardError.write(data)
    }
}
