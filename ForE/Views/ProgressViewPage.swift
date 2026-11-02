import Charts
import ForECore
import SwiftUI

struct ProgressViewPage: View {
    @EnvironmentObject private var model: AppModel
    @State private var showWeeks = false
    @State private var weekOffset = 0

    private var displayedDays: [FocusDay] {
        let stats = model.statistics
        return stats.currentWeekDays.map { day in
            let date = stats.calendar.date(byAdding: .weekOfYear, value: weekOffset, to: day.date)!
            return FocusDay(date: date, seconds: stats.seconds(on: date))
        }
    }

    private var weekCaption: String {
        guard weekOffset != 0, let first = displayedDays.first, let last = displayedDays.last else {
            return "Deine aktuelle Woche"
        }
        return "\(first.date.formatted(.dateTime.day().month(.abbreviated))) – \(last.date.formatted(.dateTime.day().month(.abbreviated).year()))"
    }

    var body: some View {
        let stats = model.statistics
        VStack(alignment: .leading, spacing: 26) {
            PageHeading(eyebrow: "Aus kleinen Momenten wird etwas Großes.", title: "Dein Fokus trägt Früchte.",
                subtitle: "Deine protokollierten Fokusmomente – ganz ohne Vergleiche mit anderen.")
            HStack(spacing: 14) {
                StatCard(icon: "clock", title: "INSGESAMT", value: focusDuration(stats.totalSeconds), detail: "Jede bewusste Minute zählt.")
                StatCard(icon: "calendar", title: "DIESE WOCHE", value: focusDuration(stats.weekSeconds), detail: "Montag bis Sonntag")
                StatCard(icon: "sparkles", title: "DEIN LEVEL", value: "Level \(stats.level)", detail: "\(stats.xp) XP · 1 XP pro Fokusminute")
            }

            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Zeit für das Wesentliche").font(.system(size: 17, weight: .semibold, design: .rounded))
                        Text(showWeeks ? "Die letzten acht Wochen" : weekCaption)
                            .font(.system(size: 11)).foregroundStyle(ForestStyle.muted)
                    }
                    Spacer()
                    Picker("Zeitraum", selection: $showWeeks) {
                        Text("Tage").tag(false)
                        Text("Wochen").tag(true)
                    }.pickerStyle(.segmented).frame(width: 180)
                }
                if showWeeks {
                    Chart(stats.recentWeeks) { week in
                        BarMark(x: .value("Woche", week.start, unit: .weekOfYear),
                                y: .value("Minuten", week.seconds / 60))
                            .foregroundStyle(ForestStyle.green.gradient).cornerRadius(5)
                            .accessibilityLabel("Woche ab \(week.start.formatted(date: .abbreviated, time: .omitted))")
                            .accessibilityValue(focusDuration(week.seconds))
                    }
                    .chartXAxis {
                        AxisMarks(values: stats.recentWeeks.map(\.start)) { value in
                            AxisValueLabel(format: .dateTime.day().month(.twoDigits))
                        }
                    }.chartYScale(domain: 0...max(60, (stats.recentWeeks.map(\.seconds).max() ?? 0) / 60 * 1.2))
                        .frame(height: 180)
                } else {
                    HStack {
                        Button { weekOffset -= 1 } label: { Image(systemName: "chevron.left") }
                            .accessibilityLabel("Vorherige Woche")
                        Button("Diese Woche") { weekOffset = 0 }.disabled(weekOffset == 0)
                        Button { weekOffset += 1 } label: { Image(systemName: "chevron.right") }
                            .disabled(weekOffset >= 0).accessibilityLabel("Nächste Woche")
                        Spacer()
                    }.buttonStyle(.bordered).controlSize(.small)
                    Chart {
                        ForEach(displayedDays) { day in
                            BarMark(x: .value("Tag", day.date, unit: .day),
                                    y: .value("Minuten", day.seconds / 60))
                                .foregroundStyle(Calendar.current.isDateInToday(day.date) ? ForestStyle.green : ForestStyle.green.opacity(0.45))
                                .cornerRadius(5)
                                .accessibilityLabel(day.date.formatted(date: .complete, time: .omitted))
                                .accessibilityValue(focusDuration(day.seconds))
                        }
                        RuleMark(y: .value("Tagesziel", model.data.dailyGoalMinutes))
                            .foregroundStyle(ForestStyle.gold.opacity(0.45))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    }
                    .chartXAxis { AxisMarks(values: .stride(by: .day)) { _ in AxisValueLabel(format: .dateTime.weekday(.abbreviated)) } }
                    .chartYScale(domain: 0...max(Double(model.data.dailyGoalMinutes) * 1.2,
                        (displayedDays.map(\.seconds).max() ?? 0) / 60 * 1.2))
                    .frame(height: 180)
                }
                HStack {
                    Label("Fokuszeit in Minuten", systemImage: "circle.fill").foregroundStyle(ForestStyle.green)
                    Spacer()
                    if !showWeeks { Text("Gestrichelte Linie: dein Tagesziel").foregroundStyle(ForestStyle.muted) }
                }.font(.system(size: 10))
                Text("Laufende Sitzungen erscheinen nach ihrem Abschluss. Vorzeitig beendete Sitzungen zählen bis zum Ende des Fokusmoments. Der Verlauf ist ein Zeitprotokoll und kein Nachweis einer durchgehend wirksamen App-Sperre.")
                    .font(.system(size: 10)).foregroundStyle(ForestStyle.muted).lineSpacing(3)
            }.environment(\.calendar, stats.calendar)
                .foregroundStyle(ForestStyle.ink).forestCard()

            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("Dein kleiner Wald").font(.system(size: 17, weight: .semibold, design: .rounded))
                    Spacer()
                    Text("\(stats.treesCount) Bäume").font(.system(size: 12)).foregroundStyle(ForestStyle.green)
                }
                if stats.treesCount == 0 {
                    HStack(spacing: 22) {
                        FocusTree(growth: 0.25).frame(width: 78, height: 95)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Hier beginnt dein Wald.").font(.system(size: 14, weight: .semibold))
                            Text("Beende deine erste Sitzung und pflanze einen Baum.\nMit jeder vollständigen Sitzung wächst dein Wald.")
                                .font(.system(size: 12)).foregroundStyle(ForestStyle.muted).lineSpacing(4)
                        }
                        Spacer()
                        Button("Loslegen") { model.page = .focus }.buttonStyle(.bordered)
                    }
                } else {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 10) {
                        ForEach(0..<min(24, stats.treesCount), id: \.self) { index in
                            FocusTree(variant: index).frame(height: 90)
                                .accessibilityLabel("Fokusbaum \(index + 1)")
                        }
                    }
                    if stats.treesCount > 24 {
                        Text("Und \(stats.treesCount - 24) weitere Bäume in deinem Wald.")
                            .font(.system(size: 11)).foregroundStyle(ForestStyle.muted)
                    }
                }
            }.foregroundStyle(ForestStyle.ink).forestCard()

            if !model.data.sessions.isEmpty { history }
        }
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Deine letzten Fokusmomente").font(.system(size: 17, weight: .semibold, design: .rounded))
            ForEach(Array(model.data.sessions.sorted { $0.startedAt > $1.startedAt }.prefix(10))) { session in
                HStack(spacing: 14) {
                    Image(systemName: session.completed ? "leaf.fill" : "circle.lefthalf.filled")
                        .foregroundStyle(session.completed ? ForestStyle.green : ForestStyle.gold)
                        .frame(width: 26)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.startedAt, format: .dateTime.day().month(.abbreviated).hour().minute())
                            .font(.system(size: 12, weight: .medium))
                        Text(session.completed ? "Abgeschlossen · ein neuer Baum" : "Vorzeitig beendet · Zeit gespeichert")
                            .font(.system(size: 10)).foregroundStyle(ForestStyle.muted)
                    }
                    Spacer()
                    Text(focusDuration(session.duration)).font(.system(size: 13, weight: .semibold, design: .rounded))
                }
                if session.id != model.data.sessions.sorted(by: { $0.startedAt > $1.startedAt }).prefix(10).last?.id { Divider() }
            }
        }.foregroundStyle(ForestStyle.ink).forestCard()
    }
}
