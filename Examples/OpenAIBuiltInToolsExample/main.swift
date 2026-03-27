import Foundation
import KaizoshaOpenAI

@main
struct KaizoshaOpenAIBuiltInToolsExample {
    static func main() async {
        do {
            let provider = try OpenAIProvider()
            let model = provider.responsesModel("gpt-5")
            let response = try await model.createResponse(
                OpenAIResponseRequest(
                    input: [.user("Find one recent Swift server-side update and summarize it.")],
                    nativeTools: [.webSearch()],
                    instructions: "Answer in two short bullet points."
                )
            )

            for item in response.output {
                print("item:", item.type)
            }
        } catch {
            writeToStandardError("OpenAI built-in tools example failed: \(error.localizedDescription)\n")
        }
    }

    private static func writeToStandardError(_ message: String) {
        guard let data = message.data(using: .utf8) else { return }
        FileHandle.standardError.write(data)
    }
}
