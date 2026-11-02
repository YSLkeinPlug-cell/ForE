import SwiftUI

@main
@MainActor
struct ForEApp: App {
    @NSApplicationDelegateAdaptor(ForEAppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("ForE · Screen Time", id: "main") {
            ContentView()
                .environmentObject(model)
                .onAppear { ForEAppDelegate.model = model }
                .preferredColorScheme(.light)
                .frame(minWidth: 1000, minHeight: 720)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1180, height: 820)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandMenu("Fokus") {
                Button(model.activeSession == nil ? "Fokus starten" : "Sitzung läuft") {
                    model.startSession()
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
                .disabled(!model.canStart)
            }
        }

        MenuBarExtra {
            MenuBarView().environmentObject(model)
        } label: {
            Label(model.activeSession == nil ? "ForE" : model.remainingText, systemImage: "leaf.fill")
        }
        .menuBarExtraStyle(.menu)
    }
}

private struct MenuBarView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text(model.activeSession == nil ? "Ein guter Moment für Fokus." : "Fokus · \(model.remainingText)")
        if model.activeSession != nil {
            Text("Bildschirmzeit-Auszeit · Regeln in macOS")
        }
        if model.needsRecovery { Text("Auszeit bitte in Bildschirmzeit prüfen") }
        Divider()
        Button("ForE öffnen") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        if model.activeSession == nil {
            Button("\(model.data.preferredMinutes) Minuten fokussieren") { model.startSession() }
                .disabled(!model.canStart)
        }
        Divider()
        Button("ForE beenden") { NSApp.terminate(nil) }
    }
}
