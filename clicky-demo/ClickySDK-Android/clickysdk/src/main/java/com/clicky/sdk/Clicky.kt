package com.clicky.sdk

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInRoot
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.IntRect
import com.clicky.sdk.internal.AssistantManager
import com.clicky.sdk.internal.AssistantOverlay
import com.clicky.sdk.internal.ElementRegistry
import com.clicky.sdk.internal.HighlightOverlay

// =====================================================================
// PUBLIC API — the entire integration surface
// =====================================================================
//
// Mirror of the iOS Swift Package API, ported to Jetpack Compose:
//
//   1. Wrap your root composable in ClickyAssistantHost(config = ...)
//   2. Tag guidable composables with Modifier.clickyElement("id")
//   3. Optionally call clickyScreen("ScreenName", state = "...") on screen enter
//
// That's the entire integration. Everything else is internal.

data class ClickyConfig(
    val anthropicApiKey: String,
    val appMapJson: String,
    val model: String = "claude-sonnet-4-6",
    val systemPromptOverride: String? = null,
)

internal val LocalAssistantManager = compositionLocalOf<AssistantManager?> { null }
internal val LocalElementRegistry = compositionLocalOf<ElementRegistry?> { null }

@Composable
fun ClickyAssistantHost(
    config: ClickyConfig,
    content: @Composable () -> Unit,
) {
    val context = LocalContext.current
    val assistantManager = remember { AssistantManager(config, context) }
    val elementRegistry = remember { ElementRegistry() }

    DisposableEffect(Unit) {
        onDispose { assistantManager.dispose() }
    }

    CompositionLocalProvider(
        LocalAssistantManager provides assistantManager,
        LocalElementRegistry provides elementRegistry,
    ) {
        Box(modifier = Modifier.fillMaxSize()) {
            content()
            HighlightOverlay()
            AssistantOverlay()
        }
    }
}

// Mark this composable as a guidable element. The AI can highlight it by
// referencing this elementId in its <tool>{"action":"highlight",...}</tool>
// calls. The modifier captures the composable's on-screen rect via
// onGloballyPositioned and registers it with the ElementRegistry.
fun Modifier.clickyElement(elementId: String): Modifier = this.then(
    Modifier.onGloballyPositioned { coords ->
        // We register via a side-channel because Modifier can't access
        // CompositionLocal directly. The composable layer below handles it.
        ElementRegistry.pendingUpdates[elementId] = IntRect(
            left = coords.positionInRoot().x.toInt(),
            top = coords.positionInRoot().y.toInt(),
            right = (coords.positionInRoot().x + coords.size.width).toInt(),
            bottom = (coords.positionInRoot().y + coords.size.height).toInt(),
        )
    }
)

// Report the current screen + state to the assistant. Call from inside any
// composable representing a screen — typically right at the top.
@Composable
fun ClickyScreen(id: String, state: String = "") {
    val manager = LocalAssistantManager.current ?: return
    LaunchedEffect(id, state) {
        manager.reportScreen(id, state)
    }
}
