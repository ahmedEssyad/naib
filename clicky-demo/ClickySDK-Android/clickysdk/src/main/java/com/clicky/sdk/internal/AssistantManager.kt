package com.clicky.sdk.internal

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.clicky.sdk.ClickyConfig
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import java.util.Locale
import java.util.UUID

// Central state machine for the in-app assistant. Internal to the SDK.

internal class AssistantManager(
    private val config: ClickyConfig,
    private val context: Context,
) {
    enum class Mode { COLLAPSED, EXPANDED }
    enum class VoiceInputState { IDLE, LISTENING }

    data class TranscriptEntry(
        val id: String = UUID.randomUUID().toString(),
        val role: ClaudeMessage.Role,
        val text: String,
    )

    var mode by mutableStateOf(Mode.COLLAPSED)
    var voiceInputState by mutableStateOf(VoiceInputState.IDLE)
    var inputText by mutableStateOf("")
    val transcript = mutableStateListOf<TranscriptEntry>()
    var streamingText by mutableStateOf("")
    var isStreaming by mutableStateOf(false)
    var highlightedElementId by mutableStateOf<String?>(null)
    var tooltipText by mutableStateOf<String?>(null)
    var currentScreenId by mutableStateOf("")
    var currentScreenState by mutableStateOf("")

    private val claudeApi = ClaudeApi(config.anthropicApiKey, config.model)
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var streamJob: Job? = null

    private val tts: TextToSpeech = TextToSpeech(context) { status ->
        if (status == TextToSpeech.SUCCESS) {
            tts.language = Locale.US
        }
    }

    private var speechRecognizer: SpeechRecognizer? = null

    fun toggleExpanded() {
        mode = if (mode == Mode.EXPANDED) Mode.COLLAPSED else Mode.EXPANDED
    }

    fun reportScreen(id: String, state: String) {
        currentScreenId = id
        currentScreenState = state
    }

    fun submitTextInput() {
        val trimmed = inputText.trim()
        if (trimmed.isEmpty()) return
        inputText = ""
        ask(trimmed)
    }

    fun ask(userQuestion: String) {
        transcript.add(TranscriptEntry(role = ClaudeMessage.Role.USER, text = userQuestion))
        streamingText = ""
        isStreaming = true

        val systemPrompt = buildSystemPrompt()
        val conversationSnapshot = transcript.toList().map { ClaudeMessage(it.role, it.text) }

        streamJob?.cancel()
        streamJob = scope.launch {
            val parser = ToolCallStreamParser()
            val fullProse = StringBuilder()
            claudeApi.stream(systemPrompt, conversationSnapshot) { event ->
                when (event) {
                    is ClaudeApi.StreamEvent.TextDelta -> {
                        val (prose, toolCalls) = parser.ingest(event.text)
                        if (prose.isNotEmpty()) {
                            streamingText += prose
                            fullProse.append(prose)
                        }
                        for (toolCall in toolCalls) applyToolCall(toolCall)
                    }
                    is ClaudeApi.StreamEvent.Done -> {
                        val tail = parser.flush()
                        if (tail.isNotEmpty()) {
                            streamingText += tail
                            fullProse.append(tail)
                        }
                        isStreaming = false
                        val finalText = fullProse.toString().trim()
                        if (finalText.isNotEmpty()) {
                            transcript.add(TranscriptEntry(role = ClaudeMessage.Role.ASSISTANT, text = finalText))
                            speak(finalText)
                        }
                        streamingText = ""
                    }
                    is ClaudeApi.StreamEvent.Error -> {
                        isStreaming = false
                        transcript.add(TranscriptEntry(
                            role = ClaudeMessage.Role.ASSISTANT,
                            text = "Error: ${event.message}",
                        ))
                        streamingText = ""
                    }
                }
            }
        }
    }

    private fun applyToolCall(toolCall: AssistantToolCall) {
        when (toolCall) {
            is AssistantToolCall.Highlight -> {
                highlightedElementId = toolCall.elementId
                tooltipText = null
            }
            is AssistantToolCall.ClearHighlight -> {
                highlightedElementId = null
                tooltipText = null
            }
            is AssistantToolCall.Navigate -> {
                // Host app drives navigation. Future hook: emit to a delegate callback.
            }
            is AssistantToolCall.Tooltip -> {
                highlightedElementId = toolCall.elementId
                tooltipText = toolCall.text
            }
        }
    }

    private fun buildSystemPrompt(): String {
        config.systemPromptOverride?.let { return it }
        return """
            You are an in-app AI tutor embedded inside a host Android application via ClickySDK.
            Your job is to guide users through tasks by giving short, friendly voice instructions AND by highlighting the exact UI element they should interact with next.

            The user is right now on screen: ${currentScreenId.ifEmpty { "(unknown)" }}.
            Current screen state: ${currentScreenState.ifEmpty { "(no extra state reported)" }}

            Here is the complete app map (every screen, every guidable element):
            ${config.appMapJson}

            How to respond:
            1. Speak in short, friendly sentences — this will be read aloud via text-to-speech, so keep it natural and brief (one or two sentences per step).
            2. When you want to highlight a UI element on the user's current screen, emit a tool call inline like this:
               <tool>{"action": "highlight", "elementId": "new-note-button"}</tool>
            3. To clear a highlight: <tool>{"action": "clear_highlight"}</tool>
            4. To add a labeled tooltip on an element: <tool>{"action": "tooltip", "elementId": "save-button", "text": "Tap here to save"}</tool>
            5. Only reference elementIds that exist on the user's CURRENT screen. If the user needs to navigate to a different screen first, instruct them to do so and highlight the navigation element.
            6. Give ONE step at a time. After each step, wait for the next user turn.
            7. Never invent elementIds. Never describe pixel coordinates.

            Tone: warm, concise, confident. Like a friend pointing things out.
        """.trimIndent()
    }

    private fun speak(text: String) {
        val cleaned = text.replace(Regex("<tool>[^<]*</tool>"), "")
        tts.speak(cleaned, TextToSpeech.QUEUE_FLUSH, null, UUID.randomUUID().toString())
    }

    // MARK: - Voice input (Android SpeechRecognizer)

    fun toggleVoiceInput() {
        when (voiceInputState) {
            VoiceInputState.IDLE -> startVoiceInput()
            VoiceInputState.LISTENING -> stopVoiceInput()
        }
    }

    private fun startVoiceInput() {
        if (!SpeechRecognizer.isRecognitionAvailable(context)) return
        val recognizer = SpeechRecognizer.createSpeechRecognizer(context)
        speechRecognizer = recognizer
        recognizer.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) {}
            override fun onBeginningOfSpeech() {}
            override fun onRmsChanged(rmsdB: Float) {}
            override fun onBufferReceived(buffer: ByteArray?) {}
            override fun onEndOfSpeech() {}
            override fun onError(error: Int) {
                voiceInputState = VoiceInputState.IDLE
            }
            override fun onResults(results: Bundle?) {
                val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                matches?.firstOrNull()?.let {
                    inputText = it
                    submitTextInput()
                }
                voiceInputState = VoiceInputState.IDLE
            }
            override fun onPartialResults(partialResults: Bundle?) {
                val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                matches?.firstOrNull()?.let { inputText = it }
            }
            override fun onEvent(eventType: Int, params: Bundle?) {}
        })

        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.US.toString())
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
        }
        recognizer.startListening(intent)
        voiceInputState = VoiceInputState.LISTENING
    }

    private fun stopVoiceInput() {
        speechRecognizer?.stopListening()
        speechRecognizer?.destroy()
        speechRecognizer = null
        voiceInputState = VoiceInputState.IDLE
    }

    fun dispose() {
        streamJob?.cancel()
        speechRecognizer?.destroy()
        tts.shutdown()
    }
}
