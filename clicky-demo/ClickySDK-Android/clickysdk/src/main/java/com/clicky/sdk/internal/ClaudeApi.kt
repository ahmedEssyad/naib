package com.clicky.sdk.internal

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL

// Minimal Claude streaming client. SSE-based. Mirrors the iOS ClaudeAPI.
//
// PRODUCTION NOTE: this calls api.anthropic.com directly with the key
// passed in via ClickyConfig. For real apps, point it at a proxy URL
// you control so the key isn't embedded in the binary.

internal data class ClaudeMessage(val role: Role, val text: String) {
    enum class Role { USER, ASSISTANT }
}

internal class ClaudeApi(
    private val apiKey: String,
    private val model: String,
) {
    sealed class StreamEvent {
        data class TextDelta(val text: String) : StreamEvent()
        data object Done : StreamEvent()
        data class Error(val message: String) : StreamEvent()
    }

    suspend fun stream(
        systemPrompt: String,
        conversation: List<ClaudeMessage>,
        onEvent: (StreamEvent) -> Unit,
    ) = withContext(Dispatchers.IO) {
        val url = URL("https://api.anthropic.com/v1/messages")
        val conn = url.openConnection() as HttpURLConnection
        try {
            conn.requestMethod = "POST"
            conn.doOutput = true
            conn.setRequestProperty("Content-Type", "application/json")
            conn.setRequestProperty("x-api-key", apiKey)
            conn.setRequestProperty("anthropic-version", "2023-06-01")
            conn.setRequestProperty("Accept", "text/event-stream")

            val messagesArray = JSONArray()
            for (message in conversation) {
                val obj = JSONObject()
                obj.put("role", if (message.role == ClaudeMessage.Role.USER) "user" else "assistant")
                obj.put("content", message.text)
                messagesArray.put(obj)
            }
            val payload = JSONObject()
                .put("model", model)
                .put("max_tokens", 1024)
                .put("system", systemPrompt)
                .put("stream", true)
                .put("messages", messagesArray)
            conn.outputStream.use { it.write(payload.toString().toByteArray()) }

            if (conn.responseCode != 200) {
                onEvent(StreamEvent.Error("HTTP ${conn.responseCode}"))
                return@withContext
            }

            BufferedReader(InputStreamReader(conn.inputStream)).use { reader ->
                while (true) {
                    val line = reader.readLine() ?: break
                    if (!line.startsWith("data: ")) continue
                    val dataString = line.substring("data: ".length)
                    val event = try { JSONObject(dataString) } catch (_: Exception) { continue }
                    when (event.optString("type")) {
                        "content_block_delta" -> {
                            val delta = event.optJSONObject("delta") ?: continue
                            val text = delta.optString("text")
                            if (text.isNotEmpty()) onEvent(StreamEvent.TextDelta(text))
                        }
                        "message_stop" -> {
                            onEvent(StreamEvent.Done)
                            return@withContext
                        }
                    }
                }
                onEvent(StreamEvent.Done)
            }
        } catch (e: Exception) {
            onEvent(StreamEvent.Error(e.message ?: "unknown error"))
        } finally {
            conn.disconnect()
        }
    }
}
