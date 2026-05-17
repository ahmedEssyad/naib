import Foundation

// The configuration an integrating app passes to ClickySDK when attaching
// the assistant to its root view.
//
// In production, `anthropicAPIKey` should be replaced by a `proxyURL`
// pointing to a Cloudflare Worker that holds the real key — never ship
// the raw key in a mobile binary. We keep the key here for hackathon
// simplicity; see README for the production swap.
public struct ClickyConfig {
    public let anthropicAPIKey: String
    public let appMapJSON: String
    public let model: String
    public let systemPromptOverride: String?

    public init(
        anthropicAPIKey: String,
        appMapJSON: String,
        model: String = "claude-sonnet-4-6",
        systemPromptOverride: String? = nil
    ) {
        self.anthropicAPIKey = anthropicAPIKey
        self.appMapJSON = appMapJSON
        self.model = model
        self.systemPromptOverride = systemPromptOverride
    }
}
