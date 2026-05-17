import SwiftUI

// The single view modifier that wires the entire SDK into the host app.
// Creates the shared AssistantManager and ElementRegistry, injects them
// as environment objects (so they cross sheet / nav boundaries), and
// layers the highlight overlay, cursor overlay, and assistant UI on top.

struct ClickyAssistantHostModifier: ViewModifier {
    let config: ClickyConfig

    @StateObject private var assistantManager: AssistantManager
    @StateObject private var elementRegistry: ElementRegistry

    init(config: ClickyConfig) {
        self.config = config
        let registry = ElementRegistry()
        let manager = AssistantManager(config: config, elementRegistry: registry)
        _assistantManager = StateObject(wrappedValue: manager)
        _elementRegistry = StateObject(wrappedValue: registry)
    }

    func body(content: Content) -> some View {
        ZStack {
            content
                .environmentObject(assistantManager)
                .environmentObject(elementRegistry)
            HighlightOverlayView()
                .environmentObject(elementRegistry)
                .environmentObject(assistantManager)
            CursorOverlay()
                .environmentObject(assistantManager)
                .allowsHitTesting(false)
            AssistantOverlayView()
                .environmentObject(assistantManager)
        }
    }
}

// Reports a screen id + state to the AssistantManager whenever the
// wrapped view appears or its state changes.
struct ClickyScreenReporterModifier: ViewModifier {
    let screenId: String
    let state: String

    @EnvironmentObject private var assistantManager: AssistantManager

    func body(content: Content) -> some View {
        content
            .onAppear {
                assistantManager.reportScreen(id: screenId, state: state)
            }
            .onChange(of: state) { _, newState in
                assistantManager.reportScreen(id: screenId, state: newState)
            }
    }
}
