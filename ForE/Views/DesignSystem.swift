import SwiftUI

enum ForestStyle {
    static let background = Color(hex: 0xF5F6F2)
    static let ink = Color(hex: 0x223C32)
    static let green = Color(hex: 0x337657)
    static let muted = Color(hex: 0x79867D)
    static let pale = Color(hex: 0xE9EFE6)
    static let gold = Color(hex: 0xC4954D)
    static let border = Color(hex: 0xE5E9E1)
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 255) / 255,
                  green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1)
    }
}

extension View {
    func forestCard(padding: CGFloat = 24) -> some View {
        self.padding(padding)
            .background(.white, in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(ForestStyle.border, lineWidth: 1))
    }
}

struct ForestButtonStyle: ButtonStyle {
    var secondary = false
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .padding(.horizontal, 20).padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .foregroundStyle(secondary ? ForestStyle.ink : .white)
            .background(secondary ? ForestStyle.pale : ForestStyle.green, in: RoundedRectangle(cornerRadius: 13))
            .opacity(enabled ? (configuration.isPressed ? 0.8 : 1) : 0.45)
            .contentShape(RoundedRectangle(cornerRadius: 13))
    }
}

struct Eyebrow: View {
    let text: String
    var body: some View {
        Text(text.uppercased()).font(.system(size: 10, weight: .bold, design: .rounded))
            .tracking(2).foregroundStyle(ForestStyle.muted)
    }
}

struct PageHeading: View {
    let eyebrow: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: eyebrow)
            Text(title).font(.system(size: 32, weight: .semibold, design: .rounded)).tracking(-0.8)
                .foregroundStyle(ForestStyle.ink)
            Text(subtitle).font(.system(size: 13)).foregroundStyle(ForestStyle.muted)
        }
    }
}

struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let detail: String
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon).foregroundStyle(ForestStyle.green)
                Spacer()
                Text(title).font(.system(size: 11, weight: .medium)).foregroundStyle(ForestStyle.muted)
            }
            Text(value).font(.system(size: 28, weight: .semibold, design: .rounded)).foregroundStyle(ForestStyle.ink)
            Text(detail).font(.system(size: 11)).foregroundStyle(ForestStyle.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading).forestCard(padding: 20)
    }
}

func focusDuration(_ seconds: TimeInterval) -> String {
    let minutes = max(0, Int(seconds / 60))
    if minutes < 60 { return "\(minutes) Min." }
    return "\(minutes / 60) Std. \(minutes % 60) Min."
}

/// Vector illustration: no remote assets, always sharp on Retina displays.
struct FocusTree: View {
    var growth: Double = 1
    var variant = 0
    private var treeColor: Color { variant.isMultiple(of: 2) ? ForestStyle.green : Color(hex: 0x589278) }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                Ellipse().fill(ForestStyle.ink.opacity(0.08)).frame(width: w * 0.65, height: h * 0.08)
                    .offset(y: h * 0.42)
                Path { path in
                    path.move(to: CGPoint(x: w * 0.5, y: h * 0.83))
                    path.addQuadCurve(to: CGPoint(x: w * 0.5, y: h * 0.25), control: CGPoint(x: w * 0.44, y: h * 0.5))
                }.stroke(Color(hex: 0x846C4C), style: StrokeStyle(lineWidth: w * 0.055, lineCap: .round))
                Group {
                    Ellipse().fill(treeColor.opacity(0.8)).frame(width: w * 0.5, height: h * 0.45)
                        .rotationEffect(.degrees(-28)).offset(x: -w * 0.14, y: -h * 0.05)
                    Ellipse().fill(treeColor).frame(width: w * 0.5, height: h * 0.5)
                        .rotationEffect(.degrees(25)).offset(x: w * 0.14, y: -h * 0.08)
                    Ellipse().fill(Color(hex: 0x77A388)).frame(width: w * 0.43, height: h * 0.48)
                        .rotationEffect(.degrees(-10)).offset(x: -w * 0.04, y: -h * 0.22)
                    Ellipse().fill(.white.opacity(0.09)).frame(width: w * 0.16, height: h * 0.3)
                        .rotationEffect(.degrees(-15)).offset(x: -w * 0.13, y: -h * 0.23)
                }
                .scaleEffect(0.5 + 0.5 * min(1, max(0, growth)), anchor: .bottom)
                Path { path in
                    path.move(to: CGPoint(x: w * 0.5, y: h * 0.59))
                    path.addLine(to: CGPoint(x: w * 0.32, y: h * 0.42))
                    path.move(to: CGPoint(x: w * 0.49, y: h * 0.49))
                    path.addLine(to: CGPoint(x: w * 0.65, y: h * 0.32))
                }.stroke(Color(hex: 0xD1DFCC).opacity(0.7), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            }
        }
        .accessibilityLabel("Ein wachsender Fokusbaum")
    }
}
