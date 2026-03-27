import Foundation
import KaizoshaGoogle
import KaizoshaProvider

@main
struct KaizoshaGoogleFilesExample {
    static func main() async {
        do {
            let provider = try GoogleProvider()
            let file = try await provider.files.upload(
                data: Data("Swift actors protect mutable state.".utf8),
                fileName: "swift-notes.txt",
                mimeType: "text/plain"
            )

            let promptFile = try file.asFileContent()
            let response = try await provider.languageModel("gemini-2.5-flash").generate(
                request: TextGenerationRequest(
                    messages: [
                        .user(parts: [
                            .text("Summarize the attached file."),
                            .file(promptFile),
                        ]),
                    ]
                )
            )

            print(response.text)
        } catch {
            writeToStandardError("Google files example failed: \(error.localizedDescription)\n")
        }
    }

    private static func writeToStandardError(_ message: String) {
        guard let data = message.data(using: .utf8) else { return }
        FileHandle.standardError.write(data)
    }
}
