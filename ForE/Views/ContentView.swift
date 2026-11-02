import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            ScrollView {
                Group {
                    switch model.page {
                    case .focus: FocusView()
                    case .websites: WebsitesView()
                    case .progress: ProgressViewPage()
                    case .settings: SettingsView()
                    }
                }.padding(36).frame(maxWidth: 1120)
                    .frame(maxWidth: .infinity)
            }.background(ForestStyle.background)
        }
        .tint(ForestStyle.green)
        .alert(item: $model.notice) { notice in
            Alert(title: Text(notice.title), message: Text(notice.message), dismissButton: .default(Text("Verstanden")))
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "leaf.fill").font(.system(size: 23))
                    .foregroundStyle(ForestStyle.green)
                Text("ForE").font(.system(size: 27, weight: .bold, design: .rounded)).tracking(-1)
            }.foregroundStyle(ForestStyle.ink).padding(.bottom, 5)
            Text("FOCUS MEETS SCREEN TIME.").font(.system(size: 8, weight: .semibold))
                .tracking(1.2).foregroundStyle(ForestStyle.muted)
                .padding(.bottom, 10)
            Text("PROTOTYP · EXPERIMENTELL").font(.system(size: 8, weight: .semibold))
                .tracking(1).foregroundStyle(ForestStyle.gold).padding(.bottom, 28)

            Eyebrow(text: "Dein Freiraum").padding(.bottom, 16)
            ForEach(AppPage.allCases, id: \.self) { page in
                Button {
                    model.page = page
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: page.icon).font(.system(size: 17)).frame(width: 21)
                        Text(page.rawValue).font(.system(size: 13, weight: model.page == page ? .semibold : .medium))
                        Spacer()
                        if page == .focus && model.activeSession != nil {
                            Circle().fill(ForestStyle.green).frame(width: 6, height: 6)
                        }
                    }
                    .foregroundStyle(model.page == page ? ForestStyle.green : ForestStyle.muted)
                    .padding(.horizontal, 14).padding(.vertical, 13)
                    .background(model.page == page ? ForestStyle.pale : .clear, in: RoundedRectangle(cornerRadius: 12))
                    .contentShape(Rectangle())
                }.buttonStyle(.plain).padding(.bottom, 6)
            }

            Spacer(minLength: 30)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "sparkles").foregroundStyle(ForestStyle.gold)
                    Text("Level \(model.statistics.level)").font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Text("\(model.statistics.xp) XP").font(.system(size: 10)).foregroundStyle(ForestStyle.muted)
                }
                ProgressView(value: model.statistics.levelProgress).tint(ForestStyle.green)
                Text("Jede Fokusminute lässt dich wachsen.")
                    .font(.system(size: 10)).foregroundStyle(ForestStyle.muted).lineSpacing(4)
            }.padding(16).background(ForestStyle.background, in: RoundedRectangle(cornerRadius: 16))
            HStack(spacing: 6) {
                Image(systemName: "lock.shield").font(.system(size: 10))
                Text("Lokal. Privat. Dein Fokus.").font(.system(size: 10))
            }.foregroundStyle(ForestStyle.muted).padding(.top, 22)
        }
        .padding(.horizontal, 22).padding(.top, 55).padding(.bottom, 26)
        .frame(width: 224).frame(maxHeight: .infinity)
        .background(.white)
        .overlay(alignment: .trailing) { Rectangle().fill(ForestStyle.border).frame(width: 1) }
    }
}
