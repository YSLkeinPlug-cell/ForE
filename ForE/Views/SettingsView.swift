import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            PageHeading(eyebrow: "Fokus nach deinen Regeln.", title: "Ein guter Rahmen für dich.",
                subtitle: "Kleine Einstellungen. Ein bisschen mehr Ruhe im Alltag.")
            VStack(alignment: .leading, spacing: 22) {
                Text("Deine Routine").font(.system(size: 17, weight: .semibold, design: .rounded))
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Tägliches Fokusziel").font(.system(size: 13, weight: .medium))
                        Text("Eine Orientierung für dich – ohne Druck.").font(.system(size: 11)).foregroundStyle(ForestStyle.muted)
                    }
                    Spacer()
                    Text("\(model.data.dailyGoalMinutes) Min.").font(.system(size: 13, weight: .medium)).monospacedDigit()
                    Stepper("Tagesziel", value: Binding(get: { model.data.dailyGoalMinutes }, set: model.setGoal),
                        in: 15...480, step: 15).labelsHidden().accessibilityLabel("Tagesziel in Minuten")
                }
                Divider()
                Toggle(isOn: $model.soundEnabled) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Ein leiser Abschluss").font(.system(size: 13, weight: .medium))
                        Text("Spiele einen Ton, wenn die Sitzung bei geöffneter App endet.")
                            .font(.system(size: 11)).foregroundStyle(ForestStyle.muted)
                    }
                }.toggleStyle(.switch)
            }.forestCard()

            VStack(alignment: .leading, spacing: 18) {
                Label("So funktioniert die Auszeit", systemImage: "hourglass")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                detail("Deine Bildschirmzeit-Regeln", "Apps, Ausnahmen und Webseiten-Limits legst du selbst in macOS fest. ForE schaltet die sichtbare manuelle Auszeit-Steuerung über Bedienungshilfen um. Ein gelesener Schalter beweist keine Sperre einzelner Apps.")
                detail("Eine eigene Aktivierung zurücknehmen", "ForE merkt sich den Zustand vor dem Start. Eine bereits aktive Auszeit bleibt bestehen. Nur eine durch ForE aktivierte Auszeit wird zum Ende zurückgesetzt; bleibt der Zustand unklar, führt dich die App zur manuellen Prüfung.")
                detail("Die App muss geöffnet bleiben", "Das Fenster darf geschlossen werden; ForE läuft dann in der Menüleiste weiter. Nach Beenden, Absturz oder Neustart kann die Auszeit weiter gelten. Öffne ForE bzw. Bildschirmzeit zur Wiederherstellung. Nach dem Ruhezustand wird die abgelaufene Sitzung bei laufender App nachgeholt.")
                detail("Experimentelle Anbindung", "Die Oberfläche von Bildschirmzeit ist keine stabile Programmierschnittstelle. Die native Automation wurde hier nicht auf einem Mac validiert. Falls ein Steuerelement nicht eindeutig erkannt wird, bricht ForE ab. Ein Bildschirmzeitcode wird niemals ausgelesen oder umgangen.")
                Button("Bildschirmzeit einrichten oder prüfen") { model.page = .websites }
                    .buttonStyle(.bordered)
            }.forestCard()

            VStack(alignment: .leading, spacing: 18) {
                Label("Deine Daten bleiben bei dir", systemImage: "externaldrive")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                Text("Kein Konto. Keine Cloud. Keine Analyse-Tracker. Fokusverlauf und Wiederherstellungsstatus liegen lokal unter ~/Library/Application Support/ForE-ScreenTime. Bildschirmzeit selbst verwendet die von dir gewählten Apple-Einstellungen, einschließlich einer möglichen Synchronisierung zwischen deinen Geräten.")
                    .font(.system(size: 12)).foregroundStyle(ForestStyle.muted).lineSpacing(5)
                Text("ForE benötigt Bedienungshilfenzugriff, aber keine Administratorrechte. Die App installiert keinen privilegierten Systemhelfer und verändert keine Hosts-Datei.")
                    .font(.system(size: 12)).foregroundStyle(ForestStyle.muted).lineSpacing(5)
                Button { model.revealHistory() } label: { Label("Lokale Verlaufsdatei im Finder zeigen", systemImage: "folder") }
                    .buttonStyle(.bordered)
                Text("ForE · Screen Time · Prototyp für macOS 13 und neuer")
                    .font(.system(size: 10)).foregroundStyle(ForestStyle.muted)
            }.forestCard()
        }.foregroundStyle(ForestStyle.ink)
    }

    private func detail(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 12, weight: .semibold))
            Text(text).font(.system(size: 12)).foregroundStyle(ForestStyle.muted).lineSpacing(5)
        }
    }
}
