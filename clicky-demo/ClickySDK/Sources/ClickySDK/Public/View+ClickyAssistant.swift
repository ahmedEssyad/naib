import SwiftUI

// Public surface of ClickySDK. An integrating app touches only these
// modifiers — everything else is internal to the package.

public extension View {

    // Attach the AI assistant overlay to your root view. Adds:
    //   • A floating sparkle/mic button bottom-right
    //   • A streaming chat panel
    //   • A highlight overlay that glows around guidable elements
    //   • A virtual cursor that flies around when the assistant acts on the app
    //   • Voice input (Apple Speech) and voice output (AVSpeech)
    //
    // Call exactly once, on the topmost view of your app.
    func clickyAssistant(config: ClickyConfig) -> some View {
        modifier(ClickyAssistantHostModifier(config: config))
    }

    // Mark this view as a guidable element. The AI can reference it by
    // elementId. The optional callbacks let the assistant act on this
    // element on the user's behalf:
    //
    //   • onTap     — invoked when Claude emits {"action":"tap","elementId":"…"}
    //   • onSetText — invoked when Claude emits {"action":"set_text","elementId":"…","value":"…"}
    //
    // Pass nil (the default) for read-only elements that should only be
    // highlighted but never auto-actuated.
    func clickyElement(
        _ elementId: String,
        onTap: (() -> Void)? = nil,
        onSetText: ((String) -> Void)? = nil
    ) -> some View {
        modifier(ClickyElementModifier(
            elementId: elementId,
            onTap: onTap,
            onSetText: onSetText
        ))
    }

    // Report the current screen + a freeform state string to the assistant.
    // The state is included in every prompt so the model always knows
    // where the user is and what's on the screen.
    func clickyScreen<State: Equatable>(id: String, state: State) -> some View {
        modifier(ClickyScreenReporterModifier(screenId: id, state: String(describing: state)))
    }

    // Convenience for screens that don't have meaningful dynamic state.
    func clickyScreen(id: String) -> some View {
        modifier(ClickyScreenReporterModifier(screenId: id, state: ""))
    }
}

// Internal ViewModifier. Reads the registry from the environment, computes
// the element's global frame via GeometryReader, and writes both frame +
// action handlers directly to the registry. Survives sheets and nav pushes
// because env propagation works across them.
struct ClickyElementModifier: ViewModifier {
    let elementId: String
    let onTap: (() -> Void)?
    let onSetText: ((String) -> Void)?

    @EnvironmentObject private var elementRegistry: ElementRegistry

    func body(content: Content) -> some View {
        content.background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear {
                        elementRegistry.updateFrame(for: elementId, frame: proxy.frame(in: .global))
                        elementRegistry.registerActions(
                            for: elementId,
                            actions: ElementActions(onTap: onTap, onSetText: onSetText)
                        )
                    }
                    .onChange(of: proxy.frame(in: .global)) { _, newFrame in
                        elementRegistry.updateFrame(for: elementId, frame: newFrame)
                    }
                    .onDisappear {
                        elementRegistry.unregisterActions(for: elementId)
                        elementRegistry.removeFrame(for: elementId)
                    }
            }
        )
    }
}
