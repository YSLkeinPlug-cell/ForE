import SwiftUI

struct FocusView: View {
    @EnvironmentObject private var model: AppModel
    @State private var confirmStop = false

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            HStack(alignment: .top) {
                PageHeading(eyebrow: "Ein bisschen Fokus. Jeden Tag.", title: "Raum für das, was zählt.",
                    subtitle: "Lass Ablenkungen los. Und deinen kleinen Wald wachsen.")
                Spacer()
                Text(model.now, format: .dateTime.day().month(.abbreviated))
                    .font(.system(size: 11, weight: .medium)).foregroundStyle(ForestStyle.muted)
                    .padding(10).background(.white, in: Capsule()).padding(.top, 8)
            }

            if model.needsRecovery {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "exclamationmark.triangle").foregroundStyle(ForestStyle.gold)
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Deine Auszeit braucht einen Blick.").font(.system(size: 13, weight: .semibold))
                        Text(model.recoveryText).font(.system(size: 11)).foregroundStyle(ForestStyle.muted)
                    }
                    Spacer()
                    Button("Prüfen") { model.page = .websites }.buttonStyle(.bordered)
                }.forestCard(padding: 18)
            }

            HStack(alignment: .top, spacing: 20) {
                timerCard.frame(maxWidth: .infinity)
                planCard.frame(width: 270)
            }

            HStack(spacing: 14) {
                StatCard(icon: "sun.max", title: "HEUTE", value: focusDuration(model.statistics.todaySeconds),
                    detail: "Tagesziel: \(model.data.dailyGoalMinutes) Minuten")
                StatCard(icon: "flame", title: "DEINE SERIE", value: "\(model.statistics.currentStreak) Tage",
                    detail: "Ein guter Tag beginnt mit Fokus.")
                StatCard(icon: "tree", title: "DEIN WALD", value: "\(model.statistics.treesCount) Bäume",
                    detail: "Ein Baum pro beendeter Sitzung.")
            }
            HStack(spacing: 12) {
                Image(systemName: "quote.opening").foregroundStyle(ForestStyle.green.opacity(0.5))
                Text("Du musst nicht alles schaffen. Nur dem Wichtigen Raum geben.")
                    .font(.system(size: 12)).foregroundStyle(ForestStyle.muted)
                Spacer()
            }.padding(.horizontal, 6)
        }
        .confirmationDialog("Fokus vorzeitig beenden?", isPresented: $confirmStop, titleVisibility: .visible) {
            Button("Auszeit zurücksetzen und beenden", role: .destructive) { model.stopSession() }
            Button("Weiter fokussieren", role: .cancel) { }
        } message: {
            Text("ForE nimmt nur die eigene Auszeit-Aktivierung zurück. Eine schon vor der Sitzung aktive Auszeit bleibt bestehen. Deine bisherige Fokuszeit zählt; ein Baum wächst erst nach einer vollständigen Sitzung.")
        }
    }

    private var timerCard: some View {
        VStack(spacing: 18) {
            HStack(spacing: 6) {
                Circle().fill(model.activeSession == nil ? ForestStyle.muted : ForestStyle.green).frame(width: 6, height: 6)
                Text(model.needsRecovery ? "AUSZEIT BITTE PRÜFEN" : (model.activeSession == nil ? "DEIN NÄCHSTER FOKUSMOMENT" : "DEIN FOKUSBAUM WÄCHST"))
                    .font(.system(size: 9, weight: .bold)).tracking(1.3)
            }.foregroundStyle(ForestStyle.green)

            ZStack {
                Circle().stroke(ForestStyle.pale, lineWidth: 5)
                Circle().trim(from: 0, to: model.sessionProgress).stroke(ForestStyle.green,
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)).rotationEffect(.degrees(-90))
                Circle().fill(ForestStyle.background).padding(15)
                FocusTree(growth: model.activeSession == nil ? 0.75 : model.sessionProgress)
                    .frame(width: 145, height: 165).offset(y: 5)
            }.frame(width: 222, height: 222)
            .animation(.easeInOut(duration: 0.8), value: model.sessionProgress)

            VStack(spacing: 5) {
                Text(model.activeSession == nil ? String(format: "%02d:00", model.data.preferredMinutes) : model.remainingText)
                    .font(.system(size: 48, weight: .light, design: .rounded)).monospacedDigit().tracking(-2)
                    .foregroundStyle(ForestStyle.ink)
                Text(timerCaption).font(.system(size: 11)).foregroundStyle(ForestStyle.muted)
                    .multilineTextAlignment(.center).frame(minHeight: 30)
            }

            if model.activeSession == nil {
                Button { model.startSession() } label: {
                    HStack(spacing: 8) {
                        if model.isBusy { ProgressView().controlSize(.small) }
                        Image(systemName: "play.fill")
                        Text(model.isBusy ? "Warte auf macOS …" : "Auszeit & Fokus starten")
                    }
                }.buttonStyle(ForestButtonStyle()).disabled(!model.canStart)
            } else {
                Button { confirmStop = true } label: {
                    Label(model.isBusy ? "Auszeit wird geprüft …" : "Sitzung beenden", systemImage: "stop.circle")
                }.buttonStyle(ForestButtonStyle(secondary: true)).disabled(model.isBusy || model.needsRecovery)
            }
            Label("ForE für das Sitzungsende geöffnet lassen", systemImage: "menubar.rectangle")
                .font(.system(size: 10)).foregroundStyle(ForestStyle.muted)
        }.frame(maxWidth: .infinity).forestCard(padding: 25)
    }

    private var timerCaption: String {
        if model.needsRecovery { return "Sitzung beendet. Prüfe den Auszeit-Zustand in macOS." }
        guard let session = model.activeSession else {
            return model.setupConfirmed ? "Ein kleiner Schritt. Ein neuer Baum." : "Richte zuerst deine Bildschirmzeit ein."
        }
        if model.remainingSeconds <= 0 { return "Fokus beendet. Die Auszeit wird geprüft …" }
        return "Fokus bis \(Date(timeIntervalSince1970: session.endsAt).formatted(date: .omitted, time: .shortened)) · Bleib beim Wesentlichen."
    }

    private var planCard: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Dein Fokusplan").font(.system(size: 17, weight: .semibold, design: .rounded))
                Text("Eine Sache nach der anderen.").font(.system(size: 11)).foregroundStyle(ForestStyle.muted)
            }
            VStack(alignment: .leading, spacing: 13) {
                Eyebrow(text: "Dauer")
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("\(model.data.preferredMinutes)").font(.system(size: 32, weight: .medium, design: .rounded))
                    Text("Minuten").font(.system(size: 12)).foregroundStyle(ForestStyle.muted)
                    Spacer()
                    Stepper("Dauer", value: Binding(get: { model.data.preferredMinutes }, set: model.setMinutes), in: 1...240, step: 5)
                        .labelsHidden().disabled(!model.canEdit).accessibilityLabel("Sitzungsdauer in Minuten")
                }
                HStack(spacing: 7) {
                    ForEach([25, 45, 60, 90], id: \.self) { minutes in
                        Button { model.setMinutes(minutes) } label: {
                            Text("\(minutes)").font(.system(size: 11, weight: .medium))
                                .frame(maxWidth: .infinity).padding(.vertical, 8)
                                .background(model.data.preferredMinutes == minutes ? ForestStyle.pale : ForestStyle.background,
                                    in: RoundedRectangle(cornerRadius: 8))
                        }.buttonStyle(.plain).disabled(!model.canEdit)
                    }
                }
                Slider(value: Binding(get: { Double(model.data.preferredMinutes) }, set: { model.setMinutes(Int($0)) }),
                    in: 1...240, step: 1).disabled(!model.canEdit)
                    .accessibilityLabel("Fokusdauer, 1 bis 240 Minuten")
            }
            Rectangle().fill(ForestStyle.border).frame(height: 1)
            VStack(alignment: .leading, spacing: 12) {
                Label("Mit macOS-Bildschirmzeit", systemImage: "hourglass")
                    .font(.system(size: 12, weight: .semibold))
                Text("Deine Regeln kommen aus „Auszeit“ und „Immer erlaubt“ in macOS. ForE liest den Auszeit-Schalter vor und nach der Änderung.")
                    .font(.system(size: 11)).foregroundStyle(ForestStyle.muted).lineSpacing(5)
                Text(model.statusText).font(.system(size: 10)).foregroundStyle(ForestStyle.muted).lineSpacing(4)
                Button { model.page = .websites } label: {
                    Label(model.setupConfirmed ? "Bildschirmzeit prüfen" : "Bildschirmzeit einrichten", systemImage: "arrow.right")
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(ForestStyle.green)
                }.buttonStyle(.plain)
            }
            Text("Auszeit-Automation · experimentell\nKeine Prüfung einzelner App-Sperren.")
                .font(.system(size: 10)).foregroundStyle(ForestStyle.muted).lineSpacing(4)
        }.foregroundStyle(ForestStyle.ink).forestCard(padding: 22)
    }
}
