import SwiftUI

/// Screen Time owns the rules. ForE only controls its visible manual Downtime override.
struct WebsitesView: View {
    @EnvironmentObject private var model: AppModel
    @State private var confirmRecovery = false
    @State private var confirmManualStart = false

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            PageHeading(eyebrow: "Ein Rahmen für deinen Freiraum.", title: "Dein Mac übernimmt die Auszeit.",
                subtitle: "Richte die Regeln in Bildschirmzeit ein. ForE verbindet sie mit deinem Fokusmoment.")

            HStack(spacing: 10) {
                Image(systemName: "wand.and.stars").foregroundStyle(ForestStyle.green)
                Text("Auszeit-Automation · experimentell")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Label(model.isTrusted ? "Bedienungshilfen erlaubt" : "Bedienungshilfen fehlen",
                    systemImage: model.isTrusted ? "checkmark.circle" : "hand.raised")
                    .font(.system(size: 11)).foregroundStyle(ForestStyle.muted)
            }.forestCard(padding: 18)

            if model.needsRecovery { recoveryCard }

            VStack(alignment: .leading, spacing: 22) {
                Text("Einmal in macOS einrichten").font(.system(size: 19, weight: .semibold, design: .rounded))
                setupStep("1", "Bildschirmzeit einschalten",
                    "Öffne Systemeinstellungen → Bildschirmzeit und aktiviere die App- & Websiteaktivität für deinen Benutzer.")
                setupStep("2", "Deinen Arbeitsraum erlauben",
                    "Wähle unter „Immer erlaubt“ ForE und die Apps aus, die du zum Arbeiten brauchst. Die übrigen Apps unterliegen während der Auszeit deinen macOS-Regeln.")
                setupStep("3", "Auszeit-Regeln festlegen",
                    "Richte bei Bedarf einen Bildschirmzeitcode ein und aktiviere „Bei Auszeit blockieren“. Ohne diese Option kann macOS die Beschränkung leichter übergehen lassen. Deinen Code verwaltest nur du; ForE liest ihn nicht.")
                setupStep("4", "Geräte bewusst wählen",
                    "Prüfe „Geräteübergreifend teilen“. Ist die Option aktiviert, kann sich Bildschirmzeit auch auf deine anderen Apple-Geräte auswirken.")
                Button { model.openScreenTime() } label: {
                    Label("Bildschirmzeit öffnen", systemImage: "arrow.up.forward.app")
                }.buttonStyle(.borderedProminent)
                Divider()
                Toggle(isOn: $model.setupConfirmed) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Ich habe die Bildschirmzeit-Regeln selbst eingerichtet")
                            .font(.system(size: 12, weight: .medium))
                        Text("Diese Bestätigung prüft keine Regeln. ForE kann App-Ausnahmen, Code und einzelne Sperren nicht auslesen.")
                            .font(.system(size: 11)).foregroundStyle(ForestStyle.muted)
                    }
                }.toggleStyle(.checkbox).disabled(!model.canEdit)
            }.forestCard()

            VStack(alignment: .leading, spacing: 20) {
                Text("Die Verbindung zu Bildschirmzeit")
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                Text("ForE bedient nach deiner Freigabe die sichtbare Auszeit-Steuerung in den Systemeinstellungen. Apple bietet dafür keine öffentliche macOS-Sperr-API. Änderungen an Sprache oder macOS-Version können die Automation unterbrechen.")
                    .font(.system(size: 12)).foregroundStyle(ForestStyle.muted).lineSpacing(5)
                HStack(spacing: 12) {
                    Button { model.requestAccessibility() } label: {
                        Label("Bedienungshilfen freigeben", systemImage: "accessibility")
                    }.buttonStyle(.bordered)
                    Button { model.checkScreenTime() } label: {
                        Label(model.isBusy ? "Wird gelesen …" : "Auszeit-Schalter lesen", systemImage: "arrow.clockwise")
                    }.buttonStyle(.bordered).disabled(model.isBusy)
                }
                HStack(spacing: 10) {
                    Circle().fill(model.downtimeEnabled == true ? ForestStyle.green : ForestStyle.gold)
                        .frame(width: 8, height: 8)
                    Text("Auszeit-Schalter: \(switchText)")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    if let checked = model.lastCheckedAt {
                        Text("Gelesen um \(checked.formatted(date: .omitted, time: .shortened))")
                            .font(.system(size: 10)).foregroundStyle(ForestStyle.muted)
                    }
                }
                Text(model.statusText).font(.system(size: 11)).foregroundStyle(ForestStyle.muted).lineSpacing(4)
                Text("Ein eingeschalteter Auszeit-Schalter bestätigt keine Sperre einzelner Apps oder Websites. Prüfe deine gewünschten Beschränkungen einmal direkt in macOS.")
                    .font(.system(size: 11)).foregroundStyle(ForestStyle.muted).lineSpacing(4)
                Divider()
                Text("Wenn die Automation deinen Mac nicht erkennt")
                    .font(.system(size: 12, weight: .semibold))
                Text("Aktiviere die Auszeit selbst in Bildschirmzeit. Du kannst dann den Fokus-Timer unabhängig von der Automation nutzen.")
                    .font(.system(size: 11)).foregroundStyle(ForestStyle.muted).lineSpacing(4)
                Button("Auszeit manuell aktivieren & Timer starten …") { confirmManualStart = true }
                    .buttonStyle(.bordered).disabled(!model.canStart)
            }.forestCard()
        }.foregroundStyle(ForestStyle.ink)
            .confirmationDialog("Wiederherstellung manuell abgeschlossen?", isPresented: $confirmRecovery,
                titleVisibility: .visible) {
                Button("Ja, ich habe die Auszeit in macOS geprüft") { model.acknowledgeManualRecovery() }
                Button("Zurück", role: .cancel) { }
            } message: {
                Text("Prüfe zuvor die Bildschirmzeit-Einstellungen und stelle den gewünschten Auszeit-Zustand selbst her. Diese Bestätigung ändert keine macOS-Einstellung und bestätigt keine Freigabe einzelner Apps.")
            }
            .confirmationDialog("Auszeit selbst aktiviert?", isPresented: $confirmManualStart,
                titleVisibility: .visible) {
                Button("Auszeit ist manuell aktiviert – Timer starten") { model.startManualSession() }
                Button("Zurück", role: .cancel) { }
            } message: {
                Text("Öffne zuvor Bildschirmzeit und aktiviere die Auszeit. ForE prüft den Schalter dabei nicht und schaltet diese Auszeit am Ende nicht aus. Stelle sie nach der Sitzung selbst zurück.")
            }
    }

    private var switchText: String {
        guard let enabled = model.downtimeEnabled else { return "Unbekannt" }
        return enabled ? "Ein" : "Aus"
    }

    private var recoveryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Auszeit bitte prüfen", systemImage: "exclamationmark.triangle")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(ForestStyle.gold)
            Text(model.recoveryText).font(.system(size: 12)).lineSpacing(5)
            HStack(spacing: 12) {
                Button("Bildschirmzeit öffnen") { model.openScreenTime() }.buttonStyle(.bordered)
                Button("Manuell geprüft …") { confirmRecovery = true }
                    .buttonStyle(.bordered).disabled(model.isBusy)
            }
        }.frame(maxWidth: .infinity, alignment: .leading).forestCard()
    }

    private func setupStep(_ number: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Text(number).font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(ForestStyle.green).frame(width: 30, height: 30)
                .background(ForestStyle.pale, in: Circle())
            VStack(alignment: .leading, spacing: 7) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(text).font(.system(size: 12)).foregroundStyle(ForestStyle.muted).lineSpacing(5)
            }
        }
    }
}
