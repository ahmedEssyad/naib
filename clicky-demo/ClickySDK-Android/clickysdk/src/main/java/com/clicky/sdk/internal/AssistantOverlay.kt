package com.clicky.sdk.internal

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowUpward
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.SolidColor
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.runtime.derivedStateOf
import com.clicky.sdk.LocalAssistantManager

@Composable
internal fun AssistantOverlay() {
    val manager = LocalAssistantManager.current ?: return

    Box(modifier = Modifier.fillMaxSize().padding(16.dp), contentAlignment = Alignment.BottomEnd) {
        Column(
            horizontalAlignment = Alignment.End,
            verticalArrangement = Arrangement.Bottom,
        ) {
            AnimatedVisibility(
                visible = manager.mode == AssistantManager.Mode.EXPANDED,
                enter = slideInVertically(initialOffsetY = { it }),
                exit = slideOutVertically(targetOffsetY = { it }),
            ) {
                ExpandedPanel()
            }
            Spacer(modifier = Modifier.height(12.dp))
            FloatingButton(onClick = { manager.toggleExpanded() })
        }
    }
}

@Composable
private fun FloatingButton(onClick: () -> Unit) {
    val manager = LocalAssistantManager.current ?: return
    Box(
        modifier = Modifier
            .size(60.dp)
            .shadow(10.dp, CircleShape)
            .background(
                Brush.linearGradient(listOf(Color(0xFF0A84FF), Color(0xFF8C5DFF))),
                CircleShape,
            )
            .clickable { onClick() },
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            imageVector = if (manager.mode == AssistantManager.Mode.EXPANDED)
                Icons.Filled.Close else Icons.Filled.AutoAwesome,
            contentDescription = "Assistant",
            tint = Color.White,
            modifier = Modifier.size(26.dp),
        )
    }
}

@Composable
private fun ExpandedPanel() {
    val manager = LocalAssistantManager.current ?: return
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(440.dp)
            .shadow(20.dp, RoundedCornerShape(20.dp))
            .background(Color(0xEB000000), RoundedCornerShape(20.dp))
            .border(1.dp, Color(0x1AFFFFFF), RoundedCornerShape(20.dp))
            .statusBarsPadding(),
    ) {
        Column(modifier = Modifier.fillMaxSize()) {
            Header(currentScreenId = manager.currentScreenId)
            TranscriptList(modifier = Modifier.weight(1f))
            InputBar()
        }
    }
}

@Composable
private fun Header(currentScreenId: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(Icons.Filled.AutoAwesome, contentDescription = null, tint = Color(0xFF0A84FF), modifier = Modifier.size(18.dp))
        Spacer(Modifier.width(8.dp))
        Text("Ask the assistant", color = Color.White, fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
        Spacer(Modifier.weight(1f))
        Text("on: $currentScreenId", color = Color(0x80FFFFFF), fontSize = 11.sp)
    }
}

@Composable
private fun TranscriptList(modifier: Modifier = Modifier) {
    val manager = LocalAssistantManager.current ?: return
    val listState = rememberLazyListState()
    val lastIndex by remember { derivedStateOf { manager.transcript.size - 1 } }

    LaunchedEffect(manager.transcript.size, manager.streamingText) {
        if (lastIndex >= 0) listState.animateScrollToItem(lastIndex)
    }

    if (manager.transcript.isEmpty() && manager.streamingText.isEmpty()) {
        EmptyHint()
        return
    }

    LazyColumn(
        modifier = modifier.fillMaxWidth(),
        state = listState,
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        items(manager.transcript, key = { it.id }) { entry ->
            TranscriptBubble(role = entry.role, text = entry.text)
        }
        if (manager.streamingText.isNotEmpty()) {
            item("streaming") {
                TranscriptBubble(role = ClaudeMessage.Role.ASSISTANT, text = manager.streamingText)
            }
        }
    }
}

@Composable
private fun EmptyHint() {
    Column(
        modifier = Modifier.fillMaxWidth().padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Text("Try asking:", color = Color(0xB3FFFFFF), fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
        Text("\"How do I create a new note?\"", color = Color(0x80FFFFFF), fontSize = 13.sp)
        Text("\"Can I set a reminder on a note?\"", color = Color(0x80FFFFFF), fontSize = 13.sp)
        Text("\"How do I delete this note?\"", color = Color(0x80FFFFFF), fontSize = 13.sp)
    }
}

@Composable
private fun TranscriptBubble(role: ClaudeMessage.Role, text: String) {
    val isUser = role == ClaudeMessage.Role.USER
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = if (isUser) Arrangement.End else Arrangement.Start,
    ) {
        Box(
            modifier = Modifier
                .background(
                    if (isUser) Color(0xFF0A84FF) else Color(0x1FFFFFFF),
                    RoundedCornerShape(12.dp),
                )
                .padding(horizontal = 12.dp, vertical = 8.dp),
        ) {
            Text(text, color = Color.White, fontSize = 14.sp)
        }
    }
}

@Composable
private fun InputBar() {
    val manager = LocalAssistantManager.current ?: return
    Row(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier = Modifier
                .weight(1f)
                .background(Color(0x14FFFFFF), RoundedCornerShape(10.dp))
                .padding(horizontal = 12.dp, vertical = 10.dp),
        ) {
            if (manager.inputText.isEmpty()) {
                Text("Ask anything…", color = Color(0x66FFFFFF), fontSize = 14.sp)
            }
            BasicTextField(
                value = manager.inputText,
                onValueChange = { manager.inputText = it },
                textStyle = TextStyle(color = Color.White, fontSize = 14.sp),
                cursorBrush = SolidColor(Color(0xFF0A84FF)),
                modifier = Modifier.fillMaxWidth(),
            )
        }
        Spacer(Modifier.width(8.dp))

        val isListening = manager.voiceInputState == AssistantManager.VoiceInputState.LISTENING
        Icon(
            imageVector = if (isListening) Icons.Filled.Stop else Icons.Filled.Mic,
            contentDescription = "Voice",
            tint = if (isListening) Color(0xFFFF453A) else Color(0xFF0A84FF),
            modifier = Modifier
                .size(28.dp)
                .clickable { manager.toggleVoiceInput() },
        )
        Spacer(Modifier.width(4.dp))
        Icon(
            imageVector = Icons.Filled.ArrowUpward,
            contentDescription = "Send",
            tint = if (manager.inputText.isBlank()) Color(0x66FFFFFF) else Color(0xFF0A84FF),
            modifier = Modifier
                .size(28.dp)
                .clickable(enabled = manager.inputText.isNotBlank()) { manager.submitTextInput() },
        )
    }
}
