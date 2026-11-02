import Combine
import Foundation

/// Small bridge between the UIKit canvas and SwiftUI's accessibility-friendly chrome.
@MainActor
final class InkCanvasController: ObservableObject {
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false
    @Published private(set) var isRefining = false
    @Published private(set) var status = "Nur Apple Pencil schreibt · Finger bewegen die Seite"
    @Published var refinementEnabled = UserDefaults.standard.object(forKey: "ink.refinement.enabled") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(refinementEnabled, forKey: "ink.refinement.enabled")
            onToggleRefinement?(refinementEnabled)
        }
    }

    var onUndo: (() -> Void)?
    var onRedo: (() -> Void)?
    var onRefine: (() -> Void)?
    var onToggleRefinement: ((Bool) -> Void)?

    func update(undo: Bool, redo: Bool, refining: Bool, status: String? = nil) {
        canUndo = undo
        canRedo = redo
        isRefining = refining
        if let status { self.status = status }
    }
}
