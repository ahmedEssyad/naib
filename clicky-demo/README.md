# ClickySDK — In-App AI Assistant for iOS & Android

> **3 lines of code to add an AI tutor that lives *inside* your app, highlights the right buttons, and walks users through tasks by voice.**

## The pitch

Every app has confused users. Today they get sent to a help center, a chatbot in a different window, or a FAQ. ClickySDK puts the assistant *inside the app*: users ask "how do I do X?" by voice or text, and the app itself lights up the right elements and walks them through it, step by step.

## Repository structure

```
clicky-mobile-demo/
├── ClickySDK-Android/             ← Jetpack Compose port (mirror of iOS SDK)
│   ├── clickysdk/                 ← library module
│   ├── demo/                      ← Android demo app
│   └── README.md
├── ClickySDK/                     ← the SDK (Swift Package, iOS)
│   ├── Package.swift
│   └── Sources/ClickySDK/
│       ├── Public/                ← the entire integration surface
│       │   ├── ClickyConfig.swift
│       │   └── View+ClickyAssistant.swift
│       └── Internal/              ← hidden from integrating apps
│           ├── AssistantManager.swift
│           ├── ClaudeAPI.swift
│           ├── ElementRegistry.swift
│           ├── ToolCall.swift
│           ├── HighlightOverlayView.swift
│           ├── AssistantOverlayView.swift
│           └── ClickyAssistantHostModifier.swift
└── ClickyDemo/                    ← a host app demonstrating integration
    ├── App.swift                  (the 3-line integration)
    ├── Models/{Note,AppMapDefinition}.swift
    └── Screens/{NotesList,CreateNote,NoteDetail}Screen.swift
```

## Integrating ClickySDK into any SwiftUI app (3 changes)

**1. Add the package** (Xcode: File → Add Package Dependencies → local path, or via `Package.swift`):

```swift
.package(path: "../ClickySDK")
```

**2. Tag guidable views** with `.clickyElement("some-id")`:

```swift
Button("Save") { save() }
    .clickyElement("save-button")
```

**3. Attach the assistant to your root view** with a config:

```swift
import ClickySDK

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .clickyAssistant(config: ClickyConfig(
                    anthropicAPIKey: "sk-ant-...",
                    appMapJSON: MyAppMap.json
                ))
        }
    }
}
```

That's the entire SDK surface. Optional: call `.clickyScreen(id:state:)` on each screen so the assistant knows where the user is and what's on screen.

## The complete public API

```swift
public struct ClickyConfig {
    public init(
        anthropicAPIKey: String,
        appMapJSON: String,
        model: String = "claude-sonnet-4-6",
        systemPromptOverride: String? = nil
    )
}

public extension View {
    func clickyAssistant(config: ClickyConfig) -> some View
    func clickyElement(_ elementId: String) -> some View
    func clickyScreen<State: Equatable>(id: String, state: State) -> some View
    func clickyScreen(id: String) -> some View
}
```

Four public symbols. That's it. Everything in `Internal/` is invisible to integrating apps.

## How it works

```
User asks (voice / text)
    ↓
ClickySDK includes current screen + app map in the system prompt
    ↓
Claude streams response. Inline tool calls embedded as <tool>{...}</tool>:
   <tool>{"action":"highlight","elementId":"new-note-button"}</tool>
    ↓
SDK parses tool calls from the stream as they arrive
    ↓
ElementRegistry resolves elementId → CGRect on screen
    ↓
HighlightOverlay glows around the element + speaks via AVSpeechSynthesizer
    ↓
User taps it → screen state changes → reported back to assistant → next step
```

### Key design decisions

| Decision | Why |
|---|---|
| **PreferenceKey for element tracking** | Layout-independent. Works on any device size, dark/light mode, dynamic type. Pixel coordinates would break the moment the app reflows. |
| **Inline `<tool>` tags in the stream** | Lets the model interleave prose and actions in one streaming response. The user hears speech AND sees the highlight at the same moment. |
| **App map in the system prompt** | The model only references elementIds that exist. No hallucinated UI. |
| **Public/Internal split** | The integrating app's autocomplete shows 4 symbols, not 30. Easy to inspect, hard to misuse. |
| **AVSpeechSynthesizer (not ElevenLabs)** | Zero extra services, zero extra cost, works offline. Trivial to swap later (see Production TODOs). |

## Run the demo

```bash
brew install xcodegen
cd /Users/admin/Desktop/clicky-mobile-demo
xcodegen generate
open ClickyDemo.xcodeproj
```

In Xcode:
1. Set your signing team.
2. Open `ClickyDemo/App.swift` and replace `PASTE_YOUR_ANTHROPIC_API_KEY_HERE` with your Anthropic API key (hackathon only — production note below).
3. Build & run on a real iPhone (mic needs hardware; simulator works for text-only).

### 90-second demo flow

1. Open app → empty Notes list.
2. Tap the sparkle button bottom-right → ask: *"How do I create a note with a reminder?"*
3. The assistant speaks while the **+** button pulses blue.
4. User taps **+** → the new screen is reported back → the **title field** lights up. The assistant says: *"Type a title here."*
5. The **reminder toggle** lights up. *"Flip this on to add a reminder."*
6. The **Save** button lights up. *"Now tap Save."*
7. Done.

## Production TODOs (post-hackathon)

- [ ] Replace `anthropicAPIKey` with a `proxyURL` pointing to a Cloudflare Worker (the Clicky macOS app's `worker/src/index.ts` is the template). Never ship API keys in a mobile binary.
- [ ] Add an `onNavigate` delegate callback to `ClickyConfig` so Claude can request screen transitions and the host app drives the actual navigation.
- [ ] Pluggable TTS provider (default: AVSpeechSynthesizer; optional: ElevenLabs for warmer voice).
- [ ] Pluggable transcription provider (default: Apple Speech; optional: AssemblyAI / Whisper).
- [ ] Auto-generate the AppMap by walking the SwiftUI navigation graph at build time, so integrators don't hand-write the JSON.
- [ ] Theme customization on `ClickyConfig` (colors, position, accent, persona).
- [ ] Analytics hook — surface which questions get asked most so product teams find UX gaps.

## Why this wins a hackathon

- **Sharp wedge.** "Drop-in SDK, 3 lines, your app gets a voice tutor." One sentence pitch.
- **Inspectable.** Judges open the code and see a clean 4-symbol public API with an internal folder doing real engineering — streaming SSE parsers, preference-key element tracking, voice in/out, structured tool calls.
- **Demo-friendly.** The 90-second flow has a wow moment every 10 seconds.
- **Real distribution story.** Show it working on the bundled demo, then say "and here's all I had to add to integrate it" — flip to `App.swift`, point to the `.clickyAssistant(config:)` line. That's the moment that closes the pitch.
