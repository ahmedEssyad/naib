package com.clicky.sdk.internal

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.clicky.sdk.LocalAssistantManager
import com.clicky.sdk.LocalElementRegistry

// Renders an animated pulsing glow + optional tooltip around the currently
// highlighted UI element. Looks up the element's rect from ElementRegistry
// by elementId.

@Composable
internal fun HighlightOverlay() {
    val assistantManager = LocalAssistantManager.current ?: return
    val elementRegistry = LocalElementRegistry.current ?: return
    val density = LocalDensity.current

    val elementId = assistantManager.highlightedElementId ?: return
    val rect = elementRegistry.frameFor(elementId) ?: return

    val infinite = rememberInfiniteTransition(label = "pulse")
    val pulse by infinite.animateFloat(
        initialValue = 0.95f,
        targetValue = 1.1f,
        animationSpec = infiniteRepeatable(
            animation = tween(1200),
            repeatMode = RepeatMode.Reverse,
        ),
        label = "pulseScale",
    )

    Box(modifier = Modifier.fillMaxSize()) {
        val inset = 6
        val offsetXDp = with(density) { (rect.left - inset).toDp() }
        val offsetYDp = with(density) { (rect.top - inset).toDp() }
        val widthDp = with(density) { (rect.width + inset * 2).toDp() }
        val heightDp = with(density) { (rect.height + inset * 2).toDp() }

        Box(
            modifier = Modifier
                .offset(x = offsetXDp, y = offsetYDp)
                .size(width = widthDp, height = heightDp)
                .scale(pulse)
                .background(Color(0x2034A8FF), RoundedCornerShape(14.dp))
                .border(3.dp, Color(0xFF0A84FF), RoundedCornerShape(14.dp))
        )

        assistantManager.tooltipText?.let { tooltip ->
            Box(
                modifier = Modifier
                    .offset(x = offsetXDp, y = with(density) { (rect.top - 40).coerceAtLeast(8).toDp() })
                    .background(Color(0xFF0A84FF), RoundedCornerShape(10.dp))
                    .padding(horizontal = 12.dp, vertical = 8.dp),
            ) {
                Text(
                    text = tooltip,
                    color = Color.White,
                    fontSize = 13.sp,
                    fontWeight = FontWeight.SemiBold,
                )
            }
        }
    }
}

// Animated-float helper used above. Compose's API uses `by` delegate via
// animateFloat on InfiniteTransition.
private fun androidx.compose.animation.core.InfiniteTransition.animateFloat(
    initialValue: Float,
    targetValue: Float,
    animationSpec: androidx.compose.animation.core.InfiniteRepeatableSpec<Float>,
    label: String,
) = androidx.compose.animation.core.animateFloat(
    initialValue = initialValue,
    targetValue = targetValue,
    animationSpec = animationSpec,
    label = label,
)
