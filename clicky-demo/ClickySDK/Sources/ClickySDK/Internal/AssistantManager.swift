import Foundation
import SwiftUI
import AVFoundation
import Speech

// Central state machine. Internal to the SDK — the host app never sees this.
//
// The new UI is driven by a single `phase` enum (Siri-style takeover →
// acting status pill → manual step pill). The underlying voice / streaming
// / walkthrough engines stay the same; phase transitions just wrap them.

// MARK: - Agent phase

enum AgentPhase: Equatable {
    case idle
    case listening(partialTranscript: String, micLevel: Float)
    case thinking(userPrompt: String)
    case acting(label: String, current: Int, total: Int)
    case guiding(stepIndex: Int, total: Int)
}

@MainActor
final class AssistantManager: NSObject, ObservableObject {
    enum VoiceInputState { case idle, listening }

    // The single source of truth every overlay surface reads from.
    @Published var phase: AgentPhase = .idle

    // Element + walkthrough state — read by the highlight + cursor overlays.
    @Published var highlightedElementId: String? = nil
    @Published var tooltipText: String? = nil
    @Published var walkthroughSteps: [WalkthroughStep] = []
    @Published var currentStepIndex: Int = 0
    @Published var cursorPosition: CGPoint? = nil
    @Published var cursorIsClicking: Bool = false

    // Screen context — set by .clickyScreen modifiers in the host app.
    @Published var currentScreenId: String = ""
    @Published var currentScreenState: String = ""

    var currentStep: WalkthroughStep? {
        guard currentStepIndex < walkthroughSteps.count else { return nil }
        return walkthroughSteps[currentStepIndex]
    }

    private let config: ClickyConfig
    private let claudeAPI: ClaudeAPI
    private let speechSynthesizer = AVSpeechSynthesizer()
    private weak var elementRegistry: ElementRegistry?
    private var autoExecuteTask: Task<Void, Never>?
    private var voiceInputState: VoiceInputState = .idle
    private var partialTranscript: String = ""
    private var lastAudioLevel: Float = 0

    private var speechRecognizer: SFSpeechRecognizer?
    private var audioEngine: AVAudioEngine?
    private var speechRequest: SFSpeechAudioBufferRecognitionRequest?
    private var speechTask: SFSpeechRecognitionTask?

    init(config: ClickyConfig, elementRegistry: ElementRegistry) {
        self.config = config
        self.claudeAPI = ClaudeAPI(apiKey: config.anthropicAPIKey, model: config.model)
        self.elementRegistry = elementRegistry
        super.init()
    }

    // MARK: - Screen reporting

    func reportScreen(id: String, state: String) {
        currentScreenId = id
        currentScreenState = state
    }

    // Suggestion chips shown beneath the waveform in the Siri takeover.
    // Hard-coded per screen for v1 — a future ClickyConfig.suggestionsProvider
    // callback would let the host app supply these dynamically.
    func suggestionsForCurrentScreen() -> [String] {
        switch currentScreenId {
        case "DocumentsHomeScreen":
            return [
                "Create an invoice for John Smith",
                "How do I make a new document?",
            ]
        case "TemplatePickerScreen":
            return [
                "Open the invoice template",
                "Which template should I pick for billing?",
            ]
        case "InvoiceEditorScreen":
            return [
                "Fill this for 3 hours of consulting at 150",
                "Add a 20% tax line",
                "How do I save this?",
            ]
        case "DocumentPreviewScreen":
            return [
                "Share this invoice",
                "Make another for the same client",
            ]
        default:
            return ["What can I do here?"]
        }
    }

    // MARK: - Entry points called by the new UI

    func openTakeover() {
        // From .idle → start listening. Cancels any in-flight work.
        autoExecuteTask?.cancel()
        partialTranscript = ""
        phase = .listening(partialTranscript: "", micLevel: 0)
        startVoiceInput()
    }

    func cancelTakeover() {
        // From .listening or .thinking → back to idle. Release the mic, drop
        // any partial input. Does NOT cancel an in-flight Claude stream that's
        // already moved past the thinking phase.
        stopVoiceInput(submit: false)
        partialTranscript = ""
        phase = .idle
    }

    func submitPrompt(_ prompt: String) {
        // Manual submission from a suggestion chip or text field.
        stopVoiceInput(submit: false)
        partialTranscript = ""
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        phase = .thinking(userPrompt: trimmed)
        Task { await ask(trimmed) }
    }

    // MARK: - Claude

    private func ask(_ userQuestion: String) async {
        let systemPrompt = buildSystemPrompt()
        let conversation = [ClaudeMessage(role: .user, text: userQuestion)]

        var parser = ToolCallStreamParser()

        await claudeAPI.stream(systemPrompt: systemPrompt, conversation: conversation) { [weak self] event in
            guard let self else { return }
            Task { @MainActor in
                switch event {
                case .textDelta(let chunk):
                    let (_, toolCalls) = parser.ingest(chunk)
                    for toolCall in toolCalls {
                        self.applyToolCall(toolCall)
                    }
                case .done:
                    _ = parser.flush()
                    // If nothing started a walkthrough, return to idle.
                    if self.walkthroughSteps.isEmpty {
                        self.phase = .idle
                    }
                case .error(let error):
                    self.phase = .idle
                    print("[ClickySDK] Claude error:", error.localizedDescription)
                }
            }
        }
    }

    private func applyToolCall(_ toolCall: AssistantToolCall) {
        switch toolCall {
        case .highlight(let elementId):
            highlightedElementId = elementId
            tooltipText = nil
            walkthroughSteps = []
            phase = .idle
            scheduleAutoDismissForHighlight(elementId: elementId)
        case .clearHighlight:
            highlightedElementId = nil
            tooltipText = nil
            walkthroughSteps = []
            phase = .idle
        case .navigate:
            break
        case .tooltip(let elementId, let text):
            highlightedElementId = elementId
            tooltipText = text
            walkthroughSteps = []
            phase = .idle
            scheduleAutoDismissForHighlight(elementId: elementId)
        case .tap(let elementId):
            startWalkthrough(steps: [
                WalkthroughStep(elementId: elementId, text: "", executeAction: .tap)
            ])
        case .setText(let elementId, let value):
            startWalkthrough(steps: [
                WalkthroughStep(elementId: elementId, text: "", executeAction: .setText(value: value))
            ])
        case .walkthrough(let steps):
            startWalkthrough(steps: steps)
        }
    }

    // Auto-clear single-shot highlights after a few seconds so the trigger
    // pill can come back and the user isn't stuck staring at a glow with no
    // way to dismiss it. If the user asks something new in the meantime,
    // the new tool call will have already overwritten highlightedElementId
    // so this becomes a no-op (the elementId check guards against that).
    private func scheduleAutoDismissForHighlight(elementId: String) {
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            await MainActor.run {
                guard let self else { return }
                if self.highlightedElementId == elementId,
                   self.walkthroughSteps.isEmpty {
                    self.highlightedElementId = nil
                    self.tooltipText = nil
                }
            }
        }
    }

    // MARK: - Walkthrough control

    func startWalkthrough(steps: [WalkthroughStep]) {
        guard !steps.isEmpty else { return }
        autoExecuteTask?.cancel()
        walkthroughSteps = steps
        currentStepIndex = 0
        publishPhaseForCurrentStep()
        runCurrentStep()
    }

    func advanceToNextStep() {
        guard !walkthroughSteps.isEmpty else { return }
        autoExecuteTask?.cancel()
        if currentStepIndex < walkthroughSteps.count - 1 {
            currentStepIndex += 1
            publishPhaseForCurrentStep()
            runCurrentStep()
        } else {
            dismissWalkthrough()
        }
    }

    func goToPreviousStep() {
        guard !walkthroughSteps.isEmpty, currentStepIndex > 0 else { return }
        autoExecuteTask?.cancel()
        currentStepIndex -= 1
        publishPhaseForCurrentStep()
        runCurrentStep()
    }

    func dismissWalkthrough() {
        autoExecuteTask?.cancel()
        walkthroughSteps = []
        currentStepIndex = 0
        highlightedElementId = nil
        tooltipText = nil
        cursorPosition = nil
        cursorIsClicking = false
        phase = .idle
    }

    private func publishPhaseForCurrentStep() {
        guard let step = currentStep else { return }
        let total = walkthroughSteps.count
        let oneBased = currentStepIndex + 1
        if step.executeAction != nil {
            // The whole walkthrough is auto-executed.
            let label = step.text.isEmpty ? "Working on it" : step.text
            phase = .acting(label: label, current: oneBased, total: total)
        } else {
            phase = .guiding(stepIndex: currentStepIndex, total: total)
        }
    }

    private func runCurrentStep() {
        guard let step = currentStep else { return }
        highlightedElementId = step.elementId
        tooltipText = nil

        if let executeAction = step.executeAction {
            autoExecuteTask = Task { [weak self] in
                await self?.performAutoStep(step: step, executeAction: executeAction)
            }
        } else {
            cursorPosition = nil
            speak(step.text)
        }
    }

    private func performAutoStep(
        step: WalkthroughStep,
        executeAction: WalkthroughStep.ExecuteAction
    ) async {
        // Wait briefly so layout / navigation begins, then poll for the element
        // to appear (its .onAppear must fire before its frame is registered).
        // A NavigationStack push animation takes ~350–500ms, so we give it up
        // to ~2.5s before giving up. Without this, cross-screen walkthroughs
        // cascade-skip all the way to the end.
        try? await Task.sleep(nanoseconds: 200_000_000)

        guard let registry = elementRegistry else {
            advanceToNextStep()
            return
        }

        var frame: CGRect? = registry.frame(for: step.elementId)
        let pollIntervalNanos: UInt64 = 80_000_000
        let pollDeadlineNanos: UInt64 = 2_500_000_000
        var elapsedNanos: UInt64 = 0
        while frame == nil, elapsedNanos < pollDeadlineNanos {
            try? await Task.sleep(nanoseconds: pollIntervalNanos)
            if Task.isCancelled { return }
            elapsedNanos += pollIntervalNanos
            frame = registry.frame(for: step.elementId)
        }
        guard let frame else {
            print("[ClickySDK] gave up waiting for element \(step.elementId)")
            advanceToNextStep()
            return
        }

        let target = CGPoint(x: frame.midX, y: frame.midY)
        cursorPosition = target
        if !step.text.isEmpty { speak(step.text) }

        try? await Task.sleep(nanoseconds: 750_000_000)
        if Task.isCancelled { return }

        cursorIsClicking = true
        try? await Task.sleep(nanoseconds: 150_000_000)
        if Task.isCancelled { return }

        switch executeAction {
        case .tap:
            registry.performTap(on: step.elementId)
        case .setText(let value):
            registry.performSetText(value, on: step.elementId)
        }

        cursorIsClicking = false

        try? await Task.sleep(nanoseconds: 500_000_000)
        if Task.isCancelled { return }
        advanceToNextStep()
    }

    // MARK: - System prompt

    private func buildSystemPrompt() -> String {
        if let override = config.systemPromptOverride {
            return override
        }
        return """
        You are an in-app AI tutor embedded inside a host application via ClickySDK.
        Your job is to guide users through tasks by giving short, friendly voice instructions AND by highlighting the exact UI element they should interact with next.

        The user is right now on screen: \(currentScreenId.isEmpty ? "(unknown)" : currentScreenId).
        Current screen state: \(currentScreenState.isEmpty ? "(no extra state reported)" : currentScreenState)

        Here is the complete app map (every screen, every guidable element):
        \(config.appMapJSON)

        ## How to respond

        You have THREE modes. Pick the right one based on intent.

        ### MODE A — AGENT MODE (the user wants you to DO the task for them)

        Triggers: "create an invoice for John", "fill this with sample data", or anything that's a direct command rather than a question.

        Emit a walkthrough where each step has an `execute` action. The SDK will move a visible cursor to each element, click/type for the user, and auto-advance through the steps. The user just watches.

        Two executable actions:
          - `"execute":"tap"` — programmatically taps the element
          - `"execute":"set_text"` with a `"value"` — fills a text field

        Example: "Create an invoice for John Smith for 3 hours at 150 dollars":

        <tool>{"action":"walkthrough","steps":[
          {"elementId":"new-document-button","text":"Opening a new document.","execute":"tap"},
          {"elementId":"template-invoice","text":"Choosing the invoice template.","execute":"tap"},
          {"elementId":"client-name-field","text":"Adding John as the client.","execute":"set_text","value":"John Smith"},
          {"elementId":"line-description-field","text":"Describing the work.","execute":"set_text","value":"Consulting services"},
          {"elementId":"line-quantity-field","text":"Setting 3 hours.","execute":"set_text","value":"3"},
          {"elementId":"line-rate-field","text":"Rate of 150.","execute":"set_text","value":"150"},
          {"elementId":"save-invoice-button","text":"Saving the invoice.","execute":"tap"}
        ]}</tool>

        Rules for agent mode:
        - Each step's `text` is read aloud — keep it ONE short sentence in present-tense.
        - Only emit `execute` for elementIds present in the AppMap.
        - For text fields you have no value for, ask the user instead of guessing.

        ### MODE B — GUIDE MODE (the user wants to LEARN how)

        Triggers: "how do I…", "where is X?", "show me how to…".

        Emit a walkthrough WITHOUT `execute`. The user navigates manually using a small bottom step pill.

        <tool>{"action":"walkthrough","steps":[
          {"elementId":"new-document-button","text":"Tap New document on the home screen."},
          {"elementId":"template-invoice","text":"Pick the Invoice template."},
          {"elementId":"client-name-field","text":"Enter the client's name here."}
        ]}</tool>

        ### MODE C — SINGLE-POINT (one-shot lookups)

        - <tool>{"action":"highlight","elementId":"save-invoice-button"}</tool>
        - <tool>{"action":"tooltip","elementId":"save-invoice-button","text":"Tap here to save"}</tool>
        - <tool>{"action":"tap","elementId":"new-document-button"}</tool>
        - <tool>{"action":"set_text","elementId":"client-name-field","value":"John Smith"}</tool>

        ## Universal rules

        1. Keep your prose short and warm — TTS reads it aloud.
        2. Only reference elementIds that EXIST in the AppMap above.
        3. Never describe pixel coordinates.
        4. If the user asks something unrelated, politely redirect.
        5. Default to AGENT MODE for commands, GUIDE MODE for questions.

        Tone: warm, concise, confident. Like a friend doing it with you.
        """
    }

    private func speak(_ text: String) {
        let cleaned = text.replacingOccurrences(of: "<tool>[^<]*</tool>", with: "", options: .regularExpression)
        let utterance = AVSpeechUtterance(string: cleaned)
        utterance.rate = 0.5
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        speechSynthesizer.speak(utterance)
    }

    // MARK: - Voice input (Apple Speech framework)

    private func startVoiceInput() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            guard status == .authorized else { return }
            AVAudioApplication.requestRecordPermission { granted in
                guard granted else { return }
                Task { @MainActor in
                    self?.beginRecognition()
                }
            }
        }
    }

    private func beginRecognition() {
        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        speechRecognizer = recognizer
        guard let recognizer, recognizer.isAvailable else { return }

        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try? audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        speechRequest = request

        let engine = AVAudioEngine()
        audioEngine = engine
        let inputNode = engine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            request.append(buffer)
            // Quick & dirty RMS for the waveform animation.
            if let channelData = buffer.floatChannelData?[0] {
                let frameLength = Int(buffer.frameLength)
                var sum: Float = 0
                for i in 0..<frameLength {
                    let sample = channelData[i]
                    sum += sample * sample
                }
                let rms = sqrtf(sum / Float(frameLength))
                let normalized = min(1.0, rms * 12)
                Task { @MainActor in
                    self?.lastAudioLevel = normalized
                    self?.refreshListeningPhase()
                }
            }
        }
        engine.prepare()
        do {
            try engine.start()
            voiceInputState = .listening
        } catch {
            voiceInputState = .idle
            return
        }

        speechTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                Task { @MainActor in
                    self.partialTranscript = result.bestTranscription.formattedString
                    self.refreshListeningPhase()
                }
            }
            if error != nil || (result?.isFinal ?? false) {
                Task { @MainActor in
                    self.stopVoiceInput(submit: true)
                }
            }
        }
    }

    private func refreshListeningPhase() {
        if case .listening = phase {
            phase = .listening(partialTranscript: partialTranscript, micLevel: lastAudioLevel)
        }
    }

    private func stopVoiceInput(submit: Bool) {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        speechRequest?.endAudio()
        speechTask?.cancel()
        speechTask = nil
        speechRequest = nil
        audioEngine = nil
        voiceInputState = .idle
        lastAudioLevel = 0
        let trimmed = partialTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        if submit, !trimmed.isEmpty {
            partialTranscript = ""
            phase = .thinking(userPrompt: trimmed)
            Task { await ask(trimmed) }
        } else if case .listening = phase {
            // Recognizer ended with no transcript (silence, timeout, or error).
            // Don't strand the user on the takeover — drop back to idle.
            partialTranscript = ""
            phase = .idle
        }
    }
}
