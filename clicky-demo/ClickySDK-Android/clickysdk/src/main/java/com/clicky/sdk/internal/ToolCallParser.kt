package com.clicky.sdk.internal

import org.json.JSONObject

// Structured actions Claude emits inside its streamed response.
// Wire format: <tool>{"action":"highlight","elementId":"save-button"}</tool>

internal sealed class AssistantToolCall {
    data class Highlight(val elementId: String) : AssistantToolCall()
    data object ClearHighlight : AssistantToolCall()
    data class Navigate(val screenId: String) : AssistantToolCall()
    data class Tooltip(val elementId: String, val text: String) : AssistantToolCall()

    companion object {
        fun parse(jsonString: String): AssistantToolCall? {
            return try {
                val json = JSONObject(jsonString)
                when (json.optString("action")) {
                    "highlight" -> json.optString("elementId").takeIf { it.isNotEmpty() }?.let(::Highlight)
                    "clear_highlight" -> ClearHighlight
                    "navigate" -> json.optString("screen").takeIf { it.isNotEmpty() }?.let(::Navigate)
                    "tooltip" -> {
                        val elementId = json.optString("elementId")
                        val text = json.optString("text")
                        if (elementId.isNotEmpty() && text.isNotEmpty()) Tooltip(elementId, text) else null
                    }
                    else -> null
                }
            } catch (e: Exception) {
                null
            }
        }
    }
}

// Incremental stream parser. Strips <tool>...</tool> blocks out of streaming
// text chunks while returning the plain prose as it arrives. Handles partial
// tags by holding back the unprocessed tail until the next chunk completes it.
internal class ToolCallStreamParser {
    private val buffer = StringBuilder()

    data class Result(val prose: String, val toolCalls: List<AssistantToolCall>)

    fun ingest(chunk: String): Result {
        buffer.append(chunk)
        val prose = StringBuilder()
        val toolCalls = mutableListOf<AssistantToolCall>()

        while (true) {
            val openIndex = buffer.indexOf("<tool>")
            if (openIndex == -1) break
            prose.append(buffer.substring(0, openIndex))
            val afterOpen = buffer.substring(openIndex + "<tool>".length)
            val closeIndex = afterOpen.indexOf("</tool>")
            if (closeIndex == -1) {
                // Tag incomplete; keep from <tool> onward for next ingest.
                val keep = buffer.substring(openIndex)
                buffer.clear()
                buffer.append(keep)
                return Result(prose.toString(), toolCalls)
            }
            val jsonString = afterOpen.substring(0, closeIndex)
            AssistantToolCall.parse(jsonString)?.let { toolCalls.add(it) }
            val rest = afterOpen.substring(closeIndex + "</tool>".length)
            buffer.clear()
            buffer.append(rest)
        }

        // If buffer might contain start of a tag, hold it back; otherwise flush.
        val lt = buffer.indexOf("<")
        if (lt >= 0) {
            prose.append(buffer.substring(0, lt))
            val keep = buffer.substring(lt)
            buffer.clear()
            buffer.append(keep)
        } else {
            prose.append(buffer.toString())
            buffer.clear()
        }
        return Result(prose.toString(), toolCalls)
    }

    fun flush(): String {
        val tail = buffer.toString()
        buffer.clear()
        return tail
    }
}
