import Foundation

// Structured actions Claude emits inside its streamed response.
// Wire format: <tool>{"action":"highlight","elementId":"save-button"}</tool>
//
// Action shapes:
//   - Single-shot UI hints:   highlight / clear_highlight / tooltip
//   - Programmatic actions:   tap / set_text  (move cursor and act)
//   - Multi-step plan:        walkthrough     (a list of steps the user
//                                              navigates or that auto-play)
//
//     <tool>{"action":"walkthrough","steps":[
//        {"elementId":"send-money-button","text":"Tap Send.","execute":"tap"},
//        {"elementId":"amount-field","text":"Entering 250.","execute":"set_text","value":"250"},
//        {"elementId":"continue-button","text":"Tap Continue."}
//     ]}</tool>
//
// A step with no `execute` is MANUAL — the user must tap Next/Back to advance.
// A step with `execute` AUTO-PLAYS — the cursor flies, the action fires,
// then the SDK moves to the next step.

struct WalkthroughStep: Equatable {
    enum ExecuteAction: Equatable {
        case tap
        case setText(value: String)
    }

    let elementId: String
    let text: String
    let executeAction: ExecuteAction?
}

enum AssistantToolCall: Equatable {
    case highlight(elementId: String)
    case clearHighlight
    case navigate(screenId: String)
    case tooltip(elementId: String, text: String)
    case tap(elementId: String)
    case setText(elementId: String, value: String)
    case walkthrough(steps: [WalkthroughStep])

    static func parse(jsonString: String) -> AssistantToolCall? {
        guard let data = jsonString.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let action = object["action"] as? String else {
            return nil
        }
        switch action {
        case "highlight":
            if let elementId = object["elementId"] as? String {
                return .highlight(elementId: elementId)
            }
        case "clear_highlight":
            return .clearHighlight
        case "navigate":
            if let screenId = object["screen"] as? String {
                return .navigate(screenId: screenId)
            }
        case "tooltip":
            if let elementId = object["elementId"] as? String,
               let text = object["text"] as? String {
                return .tooltip(elementId: elementId, text: text)
            }
        case "tap":
            if let elementId = object["elementId"] as? String {
                return .tap(elementId: elementId)
            }
        case "set_text":
            if let elementId = object["elementId"] as? String,
               let value = object["value"] as? String {
                return .setText(elementId: elementId, value: value)
            }
        case "walkthrough":
            if let rawSteps = object["steps"] as? [[String: Any]] {
                let parsedSteps = rawSteps.compactMap(parseStep)
                if !parsedSteps.isEmpty {
                    return .walkthrough(steps: parsedSteps)
                }
            }
        default:
            return nil
        }
        return nil
    }

    private static func parseStep(_ stepObject: [String: Any]) -> WalkthroughStep? {
        guard let elementId = stepObject["elementId"] as? String,
              let text = stepObject["text"] as? String else { return nil }
        let executeAction: WalkthroughStep.ExecuteAction?
        if let executeRaw = stepObject["execute"] as? String {
            switch executeRaw {
            case "tap":
                executeAction = .tap
            case "set_text":
                let value = stepObject["value"] as? String ?? ""
                executeAction = .setText(value: value)
            default:
                executeAction = nil
            }
        } else {
            executeAction = nil
        }
        return WalkthroughStep(elementId: elementId, text: text, executeAction: executeAction)
    }
}

// Incremental stream parser. Strips <tool>...</tool> blocks out of streaming
// text chunks while returning the plain prose as it arrives. Handles partial
// tags by holding back the unprocessed tail until the next chunk completes it.
struct ToolCallStreamParser {
    private var buffer: String = ""

    mutating func ingest(_ chunk: String) -> (prose: String, toolCalls: [AssistantToolCall]) {
        buffer += chunk
        var prose = ""
        var toolCalls: [AssistantToolCall] = []

        while let openRange = buffer.range(of: "<tool>") {
            let beforeTag = buffer[..<openRange.lowerBound]
            prose += String(beforeTag)
            let afterOpen = buffer[openRange.upperBound...]
            guard let closeRange = afterOpen.range(of: "</tool>") else {
                buffer = String(buffer[openRange.lowerBound...])
                return (prose, toolCalls)
            }
            let jsonString = String(afterOpen[..<closeRange.lowerBound])
            if let toolCall = AssistantToolCall.parse(jsonString: jsonString) {
                toolCalls.append(toolCall)
            }
            buffer = String(afterOpen[closeRange.upperBound...])
        }

        if let possibleTagStart = buffer.range(of: "<") {
            prose += String(buffer[..<possibleTagStart.lowerBound])
            buffer = String(buffer[possibleTagStart.lowerBound...])
        } else {
            prose += buffer
            buffer = ""
        }
        return (prose, toolCalls)
    }

    mutating func flush() -> String {
        let tail = buffer
        buffer = ""
        return tail
    }
}
