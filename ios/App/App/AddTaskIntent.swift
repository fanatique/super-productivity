import AppIntents
import Foundation
import UIKit

/// SPIKE — not production code. Exists to answer one question empirically:
/// when Siri runs this while the app is not in the foreground, does the
/// Capacitor WebView boot (and therefore import + sync the capture), or does
/// the task sit in the App Group until the user opens the app?
///
/// Everything here writes through the existing `ShareInbox`, the same durable
/// App Group inbox the Share Extension uses, so the capture is picked up by
/// `NativeCaptureImporter` with its exactly-once semantics. Nothing new touches
/// task state, the op-log or sync.
///
/// The diagnostic goes into the capture's own text, because that is the one
/// channel guaranteed to surface later: it becomes the task's notes.
@available(iOS 16.0, *)
struct AddTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Task"
    static var description = IntentDescription("Adds a task to the Super Productivity inbox.")

    /// The whole point of the spike. `false` = Siri must handle this without
    /// bringing the app forward; if the capture then never syncs until a manual
    /// launch, this flag is what has to change (at the cost of hands-free use).
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Task", requestValueDialog: "What should the task be?")
    var taskTitle: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let capturedAt = ISO8601DateFormatter().string(from: Date())
        let sceneCount = await MainActor.run { UIApplication.shared.connectedScenes.count }
        // Reads back as the task's notes: a UI scene present means the app was
        // already running, so that run proves nothing about the cold path.
        let diagnostic = "siri-spike capturedAt=\(capturedAt) scenes=\(sceneCount)"

        try ShareInbox.save(title: taskTitle, text: diagnostic)
        return .result(dialog: "Added to Super Productivity.")
    }
}

/// Supplies the spoken phrases. `\(.applicationName)` is what makes
/// "Add a task to Super Productivity" work without the user building a
/// Shortcut by hand — the difference from the URL-scheme route documented in
/// wiki 3.01.
@available(iOS 16.0, *)
struct SuperProductivityAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddTaskIntent(),
            phrases: [
                "Add a task to \(.applicationName)",
                "New task in \(.applicationName)",
                "Capture a task in \(.applicationName)"
            ],
            shortTitle: "Add Task",
            systemImageName: "plus.circle"
        )
    }
}
