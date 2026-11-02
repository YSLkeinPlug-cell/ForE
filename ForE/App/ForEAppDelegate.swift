import AppKit

@MainActor
final class ForEAppDelegate: NSObject, NSApplicationDelegate {
    static weak var model: AppModel?

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let model = Self.model, model.activeSession != nil || model.isBusy else { return .terminateNow }
        let alert = NSAlert()
        alert.messageText = "ForE schließen, während die Auszeit bestehen kann?"
        alert.informativeText = "Die automatische Rücknahme funktioniert nur bei laufender App. Beende zuerst die Sitzung oder stelle die Auszeit in Bildschirmzeit selbst zurück. Bei einem Neustart fordert ForE eine manuelle Prüfung an."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Zur App zurück")
        alert.addButton(withTitle: "Trotzdem schließen")
        return alert.runModal() == .alertSecondButtonReturn ? .terminateNow : .terminateCancel
    }
}
