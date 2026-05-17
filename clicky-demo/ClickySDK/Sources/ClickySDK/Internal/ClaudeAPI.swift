import Foundation

struct ClaudeMessage {
    enum Role: Equatable { case user, assistant }
    let role: Role
    let text: String
}

// Minimal Claude streaming client used by the SDK.
//
// PRODUCTION NOTE: this calls api.anthropic.com directly with the key
// passed in via ClickyConfig. For real apps, point it at a proxy URL
// you control (Cloudflare Worker, your backend) so the key isn't
// embedded in the binary. The SDK boundary is designed so swapping
// the endpoint is a one-line change here.
final class ClaudeAPI {
    private let apiKey: String
    private let model: String
    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    init(apiKey: String, model: String) {
        self.apiKey = apiKey
        self.model = model
    }

    enum StreamEvent {
        case textDelta(String)
        case done
        case error(Error)
    }

    func stream(
        systemPrompt: String,
        conversation: [ClaudeMessage],
        onEvent: @escaping (StreamEvent) -> Void
    ) async {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

        let messages: [[String: Any]] = conversation.map { message in
            [
                "role": message.role == .user ? "user" : "assistant",
                "content": message.text
            ]
        }
        let payload: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "system": systemPrompt,
            "stream": true,
            "messages": messages
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                onEvent(.error(NSError(
                    domain: "ClickySDK.ClaudeAPI",
                    code: http.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"]
                )))
                return
            }
            for try await line in bytes.lines {
                guard line.hasPrefix("data: ") else { continue }
                let dataString = String(line.dropFirst("data: ".count))
                guard let data = dataString.data(using: .utf8),
                      let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let type = event["type"] as? String else {
                    continue
                }
                switch type {
                case "content_block_delta":
                    if let delta = event["delta"] as? [String: Any],
                       let text = delta["text"] as? String {
                        onEvent(.textDelta(text))
                    }
                case "message_stop":
                    onEvent(.done)
                    return
                default:
                    break
                }
            }
            onEvent(.done)
        } catch {
            onEvent(.error(error))
        }
    }
}
