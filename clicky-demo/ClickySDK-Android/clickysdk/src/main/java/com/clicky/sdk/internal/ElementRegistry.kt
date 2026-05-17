package com.clicky.sdk.internal

import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.ui.unit.IntRect
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

// Tracks the current on-screen rect (in root coordinates) of every
// composable tagged with Modifier.clickyElement("...").
//
// The Modifier writes into a process-global pendingUpdates map (because
// Modifier extensions can't read CompositionLocal directly). A background
// coroutine flushes those writes into the reactive snapshot map every
// frame so the overlay re-renders smoothly.

internal class ElementRegistry {
    val frames = mutableStateMapOf<String, IntRect>()

    fun frameFor(elementId: String): IntRect? = frames[elementId]

    init {
        CoroutineScope(Dispatchers.Main).launch {
            while (true) {
                if (pendingUpdates.isNotEmpty()) {
                    val snapshot = HashMap(pendingUpdates)
                    pendingUpdates.clear()
                    for ((id, rect) in snapshot) frames[id] = rect
                }
                delay(16) // ~60fps
            }
        }
    }

    companion object {
        // Cross-modifier sink. Modifier.clickyElement writes here; the
        // ElementRegistry instance owned by the host composable drains it.
        val pendingUpdates = mutableMapOf<String, IntRect>()
    }
}
