import SwiftUI
import ClickySDK

// THIS IS THE WHOLE INTEGRATION.
//
// 1. import ClickySDK
// 2. Tag guidable views with .clickyElement("some-id")     ← see each screen
// 3. Attach .clickyAssistant(config:) to the root view     ← below
//
// That's the entire SDK surface. Everything else is your normal SwiftUI app.

@main
struct ClickyDemoApp: App {
    var body: some Scene {
        WindowGroup {
            DocumentsHomeScreen()
                .clickyAssistant(config: ClickyConfig(
                    anthropicAPIKey: "PASTE_YOUR_ANTHROPIC_API_KEY_HERE",
                    appMapJSON: AppMapDefinition.json
                ))
        }
    }
}
