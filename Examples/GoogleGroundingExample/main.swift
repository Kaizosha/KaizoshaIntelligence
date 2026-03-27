import Foundation
import KaizoshaGoogle
import KaizoshaProvider

@main
struct KaizoshaGoogleGroundingExample {
    static func main() async {
        do {
            let provider = try GoogleProvider()
            var providerOptions = ProviderOptions()
            providerOptions.setGoogle(
                GoogleProviderOptions(
                    builtInTools: [
                        GoogleTools.googleSearch(),
                        GoogleTools.urlContext(),
                    ]
                )
            )

            let response = try await provider.languageModel("gemini-2.5-flash").generate(
                request: TextGenerationRequest(
                    prompt: "Summarize the latest Swift release in two sentences.",
                    providerOptions: providerOptions
                )
            )

            print(response.text)
        } catch {
            writeToStandardError("Google grounding example failed: \(error.localizedDescription)\n")
        }
    }

    private static func writeToStandardError(_ message: String) {
        guard let data = message.data(using: .utf8) else { return }
        FileHandle.standardError.write(data)
    }
}
