import AppKit
import ApplicationServices
import Foundation

/// The current, directly observed state of the visible Downtime control.
/// This does not prove that a particular app or website is blocked.
enum DowntimeState: String, Codable {
    case enabled
    case disabled
}

@MainActor
protocol ScreenTimeControlling: AnyObject {
    var isTrusted: Bool { get }
    func requestPermission()
    func openSettings()
    func inspect() async throws -> DowntimeState
    func setDowntime(enabled: Bool) async throws -> DowntimeState
}

enum ScreenTimeBridgeError: LocalizedError {
    case permissionRequired
    case settingsUnavailable
    case controlUnavailable
    case ambiguousControls
    case stateNotConfirmed
    case familySelection
    case accessibilityFailure
    case alreadyInRequestedState
    case obstructedSettings

    var errorDescription: String? {
        switch self {
        case .permissionRequired:
            return "Bitte erlaube ForE ScreenTime unter Datenschutz & Sicherheit → Bedienungshilfen den Zugriff."
        case .settingsUnavailable:
            return "Die Bildschirmzeit-Einstellungen konnten nicht geöffnet werden. Öffne Systemeinstellungen → Bildschirmzeit → Auszeit manuell."
        case .controlUnavailable:
            return "Der Auszeit-Schalter ist nicht eindeutig lesbar. Öffne in Bildschirmzeit die Seite Auszeit für deinen eigenen Account. Diese experimentelle Anbindung unterstützt nur eindeutig erkannte deutsche und englische Bedienelemente."
        case .ambiguousControls:
            return "Es wurden mehrere mögliche Auszeit-Bedienelemente gefunden. Es wurde nichts verändert. Bitte prüfe die Auszeit manuell."
        case .stateNotConfirmed:
            return "Die Änderung konnte nicht bestätigt werden. Prüfe die Auszeit direkt in den Systemeinstellungen; sie könnte weiterhin aktiv sein. Ein Bildschirmzeit-Code wird ausschließlich im Systemfenster eingegeben."
        case .familySelection:
            return "Es ist eine Familienauswahl sichtbar. ForE steuert keine Bildschirmzeit anderer Familienmitglieder. Wähle deinen eigenen Account und öffne Auszeit manuell."
        case .obstructedSettings:
            return "Schließe zusätzliche Systemeinstellungen-Fenster und alle Dialoge. Öffne anschließend Bildschirmzeit → Auszeit und versuche es erneut. ForE bedient keine Steuerelemente hinter einem Dialog."
        case .alreadyInRequestedState:
            return "Der Auszeit-Schalter war bereits im gewünschten Zustand. ForE hat ihn nicht verändert und übernimmt keine automatische Wiederherstellung. Bitte prüfe die Auszeit manuell."
        case .accessibilityFailure:
            return "macOS hat die Bedienungshilfen-Aktion abgelehnt. Es wurde keine bestätigte Änderung gemeldet. Bitte prüfe die Auszeit manuell."
        }
    }
}

/// Experimental UI automation, not a Screen Time configuration API.
/// Apple exposes no public native-macOS API for setting global Screen Time rules.
/// The app must remain unsandboxed, and the user must grant Accessibility access.
/// No permission prompt or system-setting change occurs during initialization.
@MainActor
final class ScreenTimeBridge: ScreenTimeControlling {
    private let driver = ScreenTimeAXDriver()
    private static let settingsURL = URL(string: "x-apple.systempreferences:com.apple.Screen-Time-Settings.extension")!

    var isTrusted: Bool { AXIsProcessTrusted() }

    func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func openSettings() {
        NSWorkspace.shared.open(Self.settingsURL)
    }

    func inspect() async throws -> DowntimeState {
        let pid = try await settingsProcess()
        return try await driver.inspect(pid: pid)
    }

    func setDowntime(enabled: Bool) async throws -> DowntimeState {
        let pid = try await settingsProcess()
        return try await driver.setDowntime(enabled: enabled, pid: pid)
    }

    private func settingsProcess() async throws -> pid_t {
        guard isTrusted else { throw ScreenTimeBridgeError.permissionRequired }
        guard NSWorkspace.shared.open(Self.settingsURL) else {
            throw ScreenTimeBridgeError.settingsUnavailable
        }
        // Await launch without blocking the main actor. This is a bounded wait.
        for _ in 0..<30 {
            try Task.checkCancellation()
            if let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.systempreferences").first {
                return app.processIdentifier
            }
            try await Task.sleep(nanoseconds: 150_000_000)
        }
        throw ScreenTimeBridgeError.settingsUnavailable
    }
}

/// AX calls are synchronous; isolate them away from the main actor. AX references
/// never escape this actor. Individual remote calls and tree walks have limits.
private actor ScreenTimeAXDriver {
    private struct Node {
        let element: AXUIElement
        let role: String
        let labels: Set<String>
        let stringValue: String?
        let enabled: Bool
    }

    private struct Scan {
        let nodes: [Node]
        let complete: Bool
    }

    private struct Control {
        let element: AXUIElement
        let observed: DowntimeState
    }

    private let downtimeNames: Set<String> = ["downtime", "auszeit"]
    private let screenTimeNames: Set<String> = ["screen time", "bildschirmzeit"]
    private let explicitEnableNames: Set<String> = [
        "turn on downtime", "turn on downtime until tomorrow", "turn on until tomorrow",
        "turn on until schedule", "auszeit aktivieren", "auszeit bis morgen aktivieren",
        "bis morgen aktivieren", "bis zum zeitplan aktivieren"
    ]
    private let explicitDisableNames: Set<String> = ["turn off downtime", "auszeit deaktivieren"]
    private let familyNames: Set<String> = ["family member", "family members", "familienmitglied", "familienmitglieder"]

    func inspect(pid: pid_t) async throws -> DowntimeState {
        try await locateControl(pid: pid, allowNavigation: true).observed
    }

    func setDowntime(enabled: Bool, pid: pid_t) async throws -> DowntimeState {
        let desired: DowntimeState = enabled ? .enabled : .disabled
        let control = try await locateControl(pid: pid, allowNavigation: true)
        guard control.observed != desired else { throw ScreenTimeBridgeError.alreadyInRequestedState }
        try Task.checkCancellation()
        // Only press the exact, uniquely identified current-state control.
        // Never edit Schedule, Block at Downtime, passcodes or Always Allowed.
        let result = AXUIElementPerformAction(control.element, kAXPressAction as CFString)
        guard result == .success else { throw ScreenTimeBridgeError.accessibilityFailure }

        // Reacquire the AX tree after the press: SwiftUI may replace its elements.
        // An unknown result is a possible change, never reported as a success.
        let deadline = ProcessInfo.processInfo.systemUptime + 6
        while ProcessInfo.processInfo.systemUptime < deadline {
            try Task.checkCancellation()
            try await Task.sleep(nanoseconds: 200_000_000)
            let remaining = deadline - ProcessInfo.processInfo.systemUptime
            guard remaining > 0 else { break }
            if let observed = try? await locateControl(pid: pid, allowNavigation: false, timeout: min(0.8, remaining)),
               observed.observed == desired { return desired }
        }
        throw ScreenTimeBridgeError.stateNotConfirmed
    }

    private func locateControl(pid: pid_t, allowNavigation: Bool, timeout: TimeInterval = 5) async throws -> Control {
        let app = AXUIElementCreateApplication(pid)
        _ = AXUIElementSetMessagingTimeout(app, 0.12)
        let deadline = ProcessInfo.processInfo.systemUptime + timeout
        var navigated = false
        repeat {
            try Task.checkCancellation()
            let snapshot = try scan(app, deadline: min(deadline, ProcessInfo.processInfo.systemUptime + 1.2))
            let nodes = snapshot.nodes
            // Partial trees cannot establish uniqueness. Never mutate from one.
            guard snapshot.complete else { throw ScreenTimeBridgeError.controlUnavailable }
            if nodes.contains(where: { $0.role == kAXPopUpButtonRole as String && !$0.labels.isDisjoint(with: familyNames) }) {
                throw ScreenTimeBridgeError.familySelection
            }
            let hasDowntime = nodes.contains { !$0.labels.isDisjoint(with: downtimeNames) || downtimeNames.contains($0.stringValue ?? "") }
            let hasScreenTimeHeading = nodes.contains { node in
                (node.role == "AXHeading" || node.role == kAXWindowRole as String)
                    && (!node.labels.isDisjoint(with: screenTimeNames) || screenTimeNames.contains(node.stringValue ?? ""))
            }
            let hasDowntimeHeading = nodes.contains { node in
                (node.role == "AXHeading" || node.role == kAXWindowRole as String)
                    && (!node.labels.isDisjoint(with: downtimeNames) || downtimeNames.contains(node.stringValue ?? ""))
            }
            var controls: [Control] = []
            for node in nodes where node.enabled {
                // A checkbox/switch must be explicitly named Auszeit/Downtime.
                // Schedule and master Screen Time switches cannot match this.
                if (hasDowntimeHeading || (hasScreenTimeHeading && hasDowntime)),
                   (node.role == kAXCheckBoxRole as String || node.role == "AXSwitch"),
                   !node.labels.isDisjoint(with: downtimeNames), let value = boolValue(node.element) {
                    controls.append(Control(element: node.element, observed: value ? .enabled : .disabled))
                } else if node.role == kAXButtonRole as String, hasDowntime && (hasScreenTimeHeading || hasDowntimeHeading) {
                    if !node.labels.isDisjoint(with: explicitEnableNames) {
                        controls.append(Control(element: node.element, observed: .disabled))
                    } else if !node.labels.isDisjoint(with: explicitDisableNames) {
                        controls.append(Control(element: node.element, observed: .enabled))
                    }
                }
            }
            if controls.count > 1 { throw ScreenTimeBridgeError.ambiguousControls }
            if let control = controls.first { return control }

            if allowNavigation, !navigated, hasScreenTimeHeading {
                let links = nodes.filter { node in
                    node.enabled && (node.role == kAXButtonRole as String || node.role == "AXLink")
                        && !node.labels.isDisjoint(with: downtimeNames)
                }
                if links.count == 1 {
                    guard AXUIElementPerformAction(links[0].element, kAXPressAction as CFString) == .success else {
                        throw ScreenTimeBridgeError.accessibilityFailure
                    }
                    navigated = true
                } else if links.count > 1 {
                    throw ScreenTimeBridgeError.ambiguousControls
                }
            }
            try await Task.sleep(nanoseconds: 200_000_000)
        } while ProcessInfo.processInfo.systemUptime < deadline
        throw ScreenTimeBridgeError.controlUnavailable
    }

    private func scan(_ app: AXUIElement, deadline: TimeInterval) throws -> Scan {
        guard let windows = attribute(app, kAXWindowsAttribute) as? [AXUIElement] else { return Scan(nodes: [], complete: false) }
        guard windows.count <= 1 else { throw ScreenTimeBridgeError.obstructedSettings }
        // Never combine context from separate windows or interact behind a sheet.
        // Never traverse other apps or menu bars. Walk only System Settings windows.
        var queue = windows.map { ($0, 0) }
        var result: [Node] = []
        var index = 0
        var seen: [CFHashCode: [AXUIElement]] = [:]
        var clipped = false
        while index < queue.count, result.count < 450, ProcessInfo.processInfo.systemUptime < deadline {
            let (element, depth) = queue[index]
            index += 1
            let hash = CFHash(element)
            guard !(seen[hash] ?? []).contains(where: { CFEqual($0, element) }) else { continue }
            seen[hash, default: []].append(element)
            let role = attribute(element, kAXRoleAttribute) as? String ?? ""
            if role == "AXSheet" || role == "AXDialog" { throw ScreenTimeBridgeError.obstructedSettings }
            if role == kAXWindowRole as String {
                let subrole = attribute(element, kAXSubroleAttribute) as? String ?? ""
                let modal = (attribute(element, "AXModal") as? NSNumber)?.boolValue ?? false
                if subrole == "AXDialog" || subrole == "AXSystemDialog" || modal {
                    throw ScreenTimeBridgeError.obstructedSettings
                }
            }
            var labels = Set<String>()
            for key in [kAXTitleAttribute, kAXDescriptionAttribute] {
                guard ProcessInfo.processInfo.systemUptime < deadline else { break }
                if let text = attribute(element, key) as? String, !text.isEmpty { labels.insert(normalize(text)) }
            }
            let stringValue = (attribute(element, kAXValueAttribute) as? String).map(normalize)
            let enabled = (attribute(element, kAXEnabledAttribute) as? NSNumber)?.boolValue ?? false
            result.append(Node(element: element, role: role, labels: labels, stringValue: stringValue, enabled: enabled))
            if ProcessInfo.processInfo.systemUptime < deadline,
               let children = attribute(element, kAXChildrenAttribute) as? [AXUIElement] {
                if depth >= 18, !children.isEmpty { clipped = true; continue }
                // Bound queued work as well as processed work.
                let capacity = max(0, 600 - queue.count)
                if children.count > capacity { clipped = true }
                queue.append(contentsOf: children.prefix(capacity).map { ($0, depth + 1) })
            }
        }
        return Scan(nodes: result, complete: index == queue.count && !clipped && ProcessInfo.processInfo.systemUptime < deadline)
    }

    private func attribute(_ element: AXUIElement, _ key: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, key as CFString, &value) == .success else { return nil }
        return value
    }

    private func boolValue(_ element: AXUIElement) -> Bool? {
        if let value = attribute(element, kAXValueAttribute) as? NSNumber {
            if value.intValue == 0 { return false }
            if value.intValue == 1 { return true }
        }
        return nil
    }

    private func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
