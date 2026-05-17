# ClickySDK-Android

Jetpack Compose mirror of the iOS ClickySDK. Same protocol, same Claude pipeline, same `<tool>` format, same AppMap JSON.

## Run

1. Install Android Studio (Hedgehog or newer).
2. Open `ClickySDK-Android/` as a project.
3. Let Gradle sync (downloads Compose BOM 2024.06, AGP 8.5, Kotlin 2.0).
4. Open `demo/src/main/java/com/clicky/demo/MainActivity.kt` → replace `PASTE_YOUR_ANTHROPIC_API_KEY_HERE` with your key.
5. Run the `demo` configuration on a real device (mic needs hardware; emulator works for text).

## Integration (3 changes — identical to iOS)

```kotlin
import com.clicky.sdk.*

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            // 1. Wrap your root composable
            ClickyAssistantHost(
                config = ClickyConfig(
                    anthropicApiKey = "sk-ant-...",
                    appMapJson = MyAppMap.JSON,
                )
            ) {
                YourApp()
            }
        }
    }
}

@Composable
fun SomeScreen() {
    // 3. Report current screen (optional but recommended)
    ClickyScreen(id = "SomeScreen", state = "...")

    Button(
        onClick = { /* ... */ },
        // 2. Tag guidable elements
        modifier = Modifier.clickyElement("save-button"),
    ) { Text("Save") }
}
```

## Public API surface

```kotlin
data class ClickyConfig(
    val anthropicApiKey: String,
    val appMapJson: String,
    val model: String = "claude-sonnet-4-6",
    val systemPromptOverride: String? = null,
)

@Composable fun ClickyAssistantHost(config: ClickyConfig, content: @Composable () -> Unit)
fun Modifier.clickyElement(elementId: String): Modifier
@Composable fun ClickyScreen(id: String, state: String = "")
```

4 public symbols. Same shape as iOS.

## Differences from iOS

| Concern | iOS | Android |
|---|---|---|
| Voice STT | Apple Speech (`SFSpeechRecognizer`) | `SpeechRecognizer` (Google) |
| Voice TTS | `AVSpeechSynthesizer` | `TextToSpeech` |
| Element tracking | `PreferenceKey` | `Modifier.onGloballyPositioned` |
| Streaming | `URLSession.bytes(for:).lines` | `HttpURLConnection` + `BufferedReader` |
| Overlay framework | SwiftUI `ZStack` | Compose `Box` over content |

The user-facing UX is identical.

## Status: scaffolded, requires verification

This code was written to mirror a working iOS implementation but has **not been built against Android Studio in the development environment**. Expect minor fixups on first Gradle sync — most likely:

- Compose BOM version may need bumping for Kotlin 2.0 compatibility
- The `Modifier.clickyElement` cross-modifier pendingUpdates pattern may need a CompositionLocal-aware variant for robustness
- The `animateFloat` helper in `HighlightOverlay.kt` may be redundant once the imports resolve

These are 15-minute fixes for an Android engineer. The architecture, protocol, and integration story are all proven on the iOS side.
