import Foundation
import KaizoshaOpenAI

@main
struct KaizoshaOpenAIRealtimeExample {
    static func main() async {
        do {
            let provider = try OpenAIProvider()
            let session = try await provider.createRealtimeClientSecret(
                OpenAIRealtimeSessionRequest(
                    modelID: "gpt-realtime",
                    instructions: "Answer briefly and naturally.",
                    outputModalities: ["audio"],
                    audio: OpenAIRealtimeAudioConfiguration(
                        output: OpenAIRealtimeOutputAudioConfiguration(voice: "marin")
                    )
                )
            )

            guard let clientSecret = session.clientSecret else {
                throw NSError(domain: "KaizoshaOpenAIRealtimeExample", code: 1)
            }

            let client = try provider.realtimeClient(
                modelID: session.modelID,
                clientSecret: clientSecret
            )

            try await client.send(.responseCreate())

            for try await event in await client.events() {
                switch event {
                case .responseTextDelta(let delta):
                    print(delta, terminator: "")
                case .responseCompleted:
                    print("")
                    return
                default:
                    continue
                }
            }
        } catch {
            writeToStandardError("OpenAI Realtime example failed: \(error.localizedDescription)\n")
        }
    }

    private static func writeToStandardError(_ message: String) {
        guard let data = message.data(using: .utf8) else { return }
        FileHandle.standardError.write(data)
    }
}
