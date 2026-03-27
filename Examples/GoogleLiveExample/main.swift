import Foundation
import KaizoshaGoogle

@main
struct KaizoshaGoogleLiveExample {
    static func main() async {
        do {
            let provider = try GoogleProvider()
            let setup = GoogleLiveSetup(
                model: "models/gemini-live-2.5-flash-preview",
                options: GoogleProviderOptions(responseModalities: ["TEXT"])
            )

            let token = try await provider.live.createAuthToken(
                GoogleLiveAuthTokenRequest(setup: setup, uses: 1)
            )

            guard let value = token.value else {
                throw NSError(domain: "KaizoshaGoogleLiveExample", code: 1)
            }

            let client = try await provider.live.connect(
                setup: setup,
                authorization: .authToken(value)
            )

            for try await event in client.events() {
                switch event {
                case .setupComplete:
                    print("Live session ready.")
                    await client.close()
                    return
                case .textDelta(let delta):
                    print(delta, terminator: "")
                default:
                    continue
                }
            }
        } catch {
            writeToStandardError("Google Live example failed: \(error.localizedDescription)\n")
        }
    }

    private static func writeToStandardError(_ message: String) {
        guard let data = message.data(using: .utf8) else { return }
        FileHandle.standardError.write(data)
    }
}
