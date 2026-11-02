import AppKit
import Combine
import ForECore
import Foundation

enum AppPage: String, CaseIterable {
    case focus = "Fokus", websites = "Bildschirmzeit", progress = "Mein Wald", settings = "Einstellungen"
    var icon: String {
        switch self {
        case .focus: return "timer"
        case .websites: return "hourglass"
        case .progress: return "leaf"
        case .settings: return "slider.horizontal.3"
        }
    }
}

struct AppNotice: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

private struct AppDocument: Codable {
    var version = 1
    var history = StoredData(domains: [])
    var lease: ScreenTimeLease?
}

/// Timer ownership and the actual macOS setting are deliberately separate.
/// An enabled Downtime control is not proof of per-app enforcement.
@MainActor
final class AppModel: ObservableObject {
    @Published var page = AppPage.focus
    @Published private(set) var data = StoredData(domains: [])
    @Published private var lease: ScreenTimeLease?
    @Published private(set) var isBusy = false
    @Published private(set) var now = Date()
    @Published private(set) var isTrusted = false
    @Published private(set) var downtimeEnabled: Bool?
    @Published private(set) var lastCheckedAt: Date?
    @Published private(set) var statusText = "Auszeit-Schalter noch nicht gelesen."
    @Published var notice: AppNotice?
    @Published var setupConfirmed = UserDefaults.standard.bool(forKey: "screenTimeSetupConfirmed") {
        didSet { UserDefaults.standard.set(setupConfirmed, forKey: "screenTimeSetupConfirmed") }
    }
    @Published var soundEnabled = UserDefaults.standard.object(forKey: "completionSound") as? Bool ?? true {
        didSet { UserDefaults.standard.set(soundEnabled, forKey: "completionSound") }
    }

    private let bridge: any ScreenTimeControlling
    private var timer: AnyCancellable?
    private let storageURL: URL
    private var storageAvailable = true

    init(bridge: (any ScreenTimeControlling)? = nil, storageURL suppliedStorageURL: URL? = nil,
         startsTimer: Bool = true) {
        self.bridge = bridge ?? ScreenTimeBridge()
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        storageURL = suppliedStorageURL ?? support.appendingPathComponent("ForE-ScreenTime", isDirectory: true)
            .appendingPathComponent("history-and-session.json")
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let document = try decoder.decode(AppDocument.self, from: Data(contentsOf: storageURL))
            guard document.version == 1 else { throw ModelError.invalidDocument }
            data = document.history
            data.preferredMinutes = min(240, max(1, data.preferredMinutes))
            data.dailyGoalMinutes = min(480, max(15, data.dailyGoalMinutes))
            if let run = document.lease {
                guard run.startedAt.isFinite, run.endsAt.isFinite, run.endsAt > run.startedAt,
                      run.startedAt >= 0, run.startedAt <= Date().timeIntervalSince1970 + 86_400,
                      run.endsAt - run.startedAt <= 240 * 60,
                      run.finishedAt?.isFinite ?? true,
                      (run.finishedAt == nil) == (run.completed == nil) else { throw ModelError.invalidDocument }
                // After a restart, intervening user changes cannot be excluded.
                // Never restore a global setting automatically from stale ownership.
                var recovered = run
                recovered.markFinished(at: min(Date().timeIntervalSince1970, run.endsAt), completed: false)
                recovered.phase = .attention
                lease = recovered
                statusText = "Vorherige Sitzung: Auszeit bitte manuell prüfen."
                _ = save()
            }
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            // A fresh install has no journal.
        } catch {
            lease = nil
            storageAvailable = false
            notice = AppNotice(title: "Lokale Daten nicht lesbar", message:
                "Die Datei bleibt unverändert. Neue Sitzungen sind bis zur Reparatur deaktiviert. \(storageURL.path)\n\(error.localizedDescription)")
        }
        isTrusted = self.bridge.isTrusted
        if startsTimer {
            timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect().sink { [weak self] _ in
                self?.tick()
            }
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification,
            object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.isTrusted = self?.bridge.isTrusted ?? false }
            }
    }

    var activeSession: ScreenTimeLease? { lease }
    var statistics: FocusStatistics { FocusStatistics(sessions: data.sessions, now: now) }
    var canStart: Bool { !isBusy && lease == nil && storageAvailable && setupConfirmed }
    var canEdit: Bool { !isBusy && lease == nil && storageAvailable }
    var needsRecovery: Bool { lease?.needsManualReview ?? false }
    var recoveryText: String {
        "Die Auszeit kann noch eingeschaltet sein. Öffne Bildschirmzeit und stelle den gewünschten Zustand selbst her. ForE schaltet nach einem Neustart oder unklarem Ergebnis nichts automatisch aus. Erst danach die Prüfung bestätigen."
    }
    var remainingSeconds: TimeInterval { min(240 * 60, max(0, (lease?.endsAt ?? now.timeIntervalSince1970) - now.timeIntervalSince1970)) }
    var remainingText: String {
        let seconds = Int(ceil(remainingSeconds))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
    var sessionProgress: Double {
        guard let run = lease else { return 0 }
        return min(1, max(0, 1 - remainingSeconds / max(1, run.endsAt - run.startedAt)))
    }

    func setMinutes(_ value: Int) {
        guard canEdit else { return }
        data.preferredMinutes = min(240, max(1, value)); _ = save()
    }

    func setGoal(_ value: Int) {
        guard storageAvailable, !isBusy else { return }
        data.dailyGoalMinutes = min(480, max(15, value)); _ = save()
    }

    func requestAccessibility() {
        bridge.requestPermission()
        isTrusted = bridge.isTrusted
    }

    func openScreenTime() { bridge.openSettings() }

    func checkScreenTime() {
        guard !isBusy else { return }
        isBusy = true
        Task {
            defer { isBusy = false; isTrusted = bridge.isTrusted }
            do {
                let state = try await bridge.inspect()
                recordObservation(state)
                // If the owned manual override disappeared, ownership is lost.
                if state == .disabled, lease?.phase == .active {
                    var run = lease!
                    run.markFinished(at: Date().timeIntervalSince1970, completed: false)
                    run.ownership = .external
                    lease = run
                    guard finishJournal() else { return }
                    notice = AppNotice(title: "Auszeit wurde ausgeschaltet", message:
                        "Die Sitzung wurde als vorzeitig beendet gespeichert. ForE schaltet die Auszeit nicht erneut ein.")
                }
            } catch { reportBridgeError(error, title: "Auszeit nicht lesbar") }
        }
    }

    func startSession() {
        guard canStart else { return }
        isTrusted = bridge.isTrusted
        guard isTrusted else {
            page = .websites
            notice = AppNotice(title: "Bedienungshilfen erforderlich", message:
                "Erlaube ForE ScreenTime unter Datenschutz & Sicherheit → Bedienungshilfen den Zugriff. Starte die Sitzung danach erneut.")
            return
        }
        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                let baseline = try await bridge.inspect()
                recordObservation(baseline)
                let start = Date().timeIntervalSince1970
                var pending = ScreenTimeLease(startedAt: start, endsAt: start + Double(data.preferredMinutes * 60))
                if baseline == .enabled {
                    pending.ownership = .external
                    pending.phase = .active
                }
                lease = pending
                // Journal before touching macOS: an interrupted operation stays visible.
                guard save() else { lease = nil; return }
                if baseline == .disabled {
                    let observed = try await bridge.setDowntime(enabled: true)
                    guard observed == .enabled else { throw ModelError.unverifiedChange }
                    recordObservation(observed)
                    let confirmedStart = Date().timeIntervalSince1970
                    pending = ScreenTimeLease(id: pending.id, startedAt: confirmedStart,
                        endsAt: confirmedStart + Double(data.preferredMinutes * 60), ownership: .app, phase: .active)
                    lease = pending
                    guard save() else {
                        lease?.phase = .attention
                        statusText = "Auszeit eingeschaltet; Journal konnte nicht gesichert werden. Bitte manuell prüfen."
                        return
                    }
                }
                statusText = baseline == .enabled
                    ? "Auszeit-Schalter: Ein. Bereits bestehende Auszeit bleibt unverändert."
                    : "Auszeit-Schalter: Ein. ForE hat die manuelle Auszeit eingeschaltet."
            } catch {
                if lease != nil { lease?.phase = .attention; _ = save() }
                reportBridgeError(error, title: "Fokus konnte nicht gestartet werden")
            }
        }
    }

    /// Explicit manual fallback. It records the user's focus time, never a
    /// technically verified Screen Time state, and never acquires ownership.
    func startManualSession() {
        guard canStart else { return }
        let start = Date().timeIntervalSince1970
        lease = ScreenTimeLease(startedAt: start, endsAt: start + Double(data.preferredMinutes * 60),
            ownership: .external, phase: .active)
        guard save() else { lease = nil; return }
        downtimeEnabled = nil
        lastCheckedAt = nil
        statusText = "Timer nach deiner Bestätigung gestartet. Auszeit nicht technisch geprüft; bitte am Ende selbst ausschalten."
        page = .focus
    }

    func stopSession() {
        guard let run = lease, !isBusy, !run.needsManualReview else { return }
        endSession(completed: Date().timeIntervalSince1970 >= run.endsAt)
    }

    private func tick() {
        now = Date()
        isTrusted = bridge.isTrusted
        if let run = lease, run.phase == .active, now.timeIntervalSince1970 >= run.endsAt, !isBusy {
            endSession(completed: true)
        }
    }

    private func endSession(completed: Bool) {
        guard var run = lease, !isBusy else { return }
        run.markFinished(at: Date().timeIntervalSince1970, completed: completed)
        lease = run
        guard save() else { lease?.phase = .attention; return }
        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                if run.canAutomaticallyRestore {
                    let observed = try await bridge.inspect()
                    recordObservation(observed)
                    if observed == .enabled {
                        let restored = try await bridge.setDowntime(enabled: false)
                        guard restored == .disabled else { throw ModelError.unverifiedChange }
                        recordObservation(restored)
                    }
                    statusText = "Auszeit-Schalter: Aus. Manuelle Auszeit beendet. Zeitpläne und Regeln bleiben in macOS."
                } else {
                    statusText = "Fokus beendet. Die vorher bestehende Auszeit bleibt unverändert."
                }
                let earnedTree = run.completed == true
                guard finishJournal() else { return }
                if run.ownership == .external {
                    if earnedTree, soundEnabled { NSSound(named: "Glass")?.play() }
                    notice = AppNotice(title: "Fokuszeit gespeichert", message:
                        "Die schon vorher oder manuell aktivierte Auszeit bleibt unverändert. Prüfe sie in Bildschirmzeit und schalte sie bei Bedarf selbst aus.")
                } else if earnedTree {
                    if soundEnabled { NSSound(named: "Glass")?.play() }
                    notice = AppNotice(title: "Ein neuer Baum für deinen Wald 🌱", message:
                        "Deine Fokuszeit wurde gespeichert. Die Wirkung deiner Bildschirmzeit-Regeln hängt weiterhin von den macOS-Einstellungen ab.")
                }
            } catch {
                lease?.phase = .attention
                _ = save()
                reportBridgeError(error, title: "Auszeit bitte manuell prüfen")
            }
        }
    }

    /// Called only after explicit confirmation that the user handled macOS manually.
    func acknowledgeManualRecovery() {
        guard var run = lease, needsRecovery, !isBusy, storageAvailable else { return }
        run.markFinished(at: Date().timeIntervalSince1970, completed: false)
        lease = run
        if finishJournal() {
            downtimeEnabled = nil
            lastCheckedAt = nil
            statusText = "Manuelle Prüfung von dir bestätigt. Auszeit-Schalter nicht neu gelesen."
        }
    }

    @discardableResult
    private func finishJournal() -> Bool {
        guard let run = lease else { return true }
        if let receipt = run.receipt(), !data.sessions.contains(where: { $0.id == receipt.id }) {
            data.sessions.append(receipt)
        }
        lease = nil
        if save() { return true }
        var pending = run; pending.phase = .attention; lease = pending
        return false
    }

    private func recordObservation(_ state: DowntimeState) {
        downtimeEnabled = state == .enabled
        lastCheckedAt = Date()
        statusText = "Auszeit-Schalter: \(state == .enabled ? "Ein" : "Aus"). App-Regeln und Code werden nicht geprüft."
    }

    private func reportBridgeError(_ error: Error, title: String) {
        downtimeEnabled = nil
        lastCheckedAt = nil
        statusText = "Auszeit-Schalter: Unbekannt. \(error.localizedDescription)"
        notice = AppNotice(title: title, message: error.localizedDescription +
            "\nDu kannst Bildschirmzeit manuell öffnen. Ein unbekannter Zustand bestätigt keine Sperre.")
        if needsRecovery { page = .websites }
    }

    func revealHistory() {
        NSWorkspace.shared.selectFile(storageURL.path,
            inFileViewerRootedAtPath: storageURL.deletingLastPathComponent().path)
    }

    @discardableResult
    private func save() -> Bool {
        guard storageAvailable else { return false }
        do {
            try FileManager.default.createDirectory(at: storageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(AppDocument(history: data, lease: lease)).write(to: storageURL, options: .atomic)
            return true
        } catch {
            storageAvailable = false
            notice = AppNotice(title: "Lokale Daten nicht gespeichert", message:
                "Neue Sitzungen sind deaktiviert. Eine laufende Auszeit kann weiterbestehen; prüfe sie in macOS. Bitte prüfe Speicherplatz und Schreibrechte und starte ForE danach erneut. \(error.localizedDescription)")
            return false
        }
    }

    private enum ModelError: LocalizedError {
        case invalidDocument, unverifiedChange
        var errorDescription: String? {
            switch self {
            case .invalidDocument: return "Ungültiges oder nicht unterstütztes Sitzungsdokument."
            case .unverifiedChange: return "macOS hat die Änderung des Auszeit-Schalters nicht bestätigt."
            }
        }
    }
}
