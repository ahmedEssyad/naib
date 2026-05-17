import SwiftUI

// A guidable UI element registers two things with this registry:
//   1. Its on-screen frame (so the highlight overlay can glow it,
//      and the cursor overlay can fly to it)
//   2. Optional action handlers (so the assistant can programmatically
//      tap it or set its text — the "agent mode" UX)
//
// Registration is imperative (via env-injected reference in onAppear)
// rather than PreferenceKey-based — that lets it work across sheets,
// fullScreenCovers, and any other view-tree boundary as long as the
// SwiftUI environment propagates the registry.

struct ElementActions {
    let onTap: (() -> Void)?
    let onSetText: ((String) -> Void)?
}

@MainActor
final class ElementRegistry: ObservableObject {
    @Published private(set) var frames: [String: CGRect] = [:]
    private var actions: [String: ElementActions] = [:]

    func updateFrame(for elementId: String, frame: CGRect) {
        if frames[elementId] != frame {
            frames[elementId] = frame
        }
    }

    func removeFrame(for elementId: String) {
        frames.removeValue(forKey: elementId)
    }

    func frame(for elementId: String) -> CGRect? {
        frames[elementId]
    }

    func registerActions(for elementId: String, actions: ElementActions) {
        self.actions[elementId] = actions
    }

    func unregisterActions(for elementId: String) {
        actions.removeValue(forKey: elementId)
    }

    @discardableResult
    func performTap(on elementId: String) -> Bool {
        guard let handler = actions[elementId]?.onTap else { return false }
        handler()
        return true
    }

    @discardableResult
    func performSetText(_ value: String, on elementId: String) -> Bool {
        guard let handler = actions[elementId]?.onSetText else { return false }
        handler(value)
        return true
    }
}
