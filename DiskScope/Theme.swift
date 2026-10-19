import SwiftUI

enum Theme {
    static let deep = Color(red: 0.031, green: 0.105, blue: 0.27)
    static let mid = Color(red: 0.039, green: 0.27, blue: 0.62)
    static let bright = Color(red: 0.067, green: 0.46, blue: 0.93)
    static let accent = Color(red: 0.34, green: 0.74, blue: 1.0)
    static let warm = Color(red: 1.0, green: 0.70, blue: 0.28)
    static let secondary = Color.white.opacity(0.62)
    static let tertiary = Color.white.opacity(0.38)
    static let hairline = Color.white.opacity(0.12)
}

struct AppBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.deep, Theme.mid, Theme.bright],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [Color.white.opacity(0.20), .clear],
                center: UnitPoint(x: 0.18, y: 0.06),
                startRadius: 0,
                endRadius: 860
            )
            .blendMode(.plusLighter)

            RadialGradient(
                colors: [Color.black.opacity(0.30), .clear],
                center: UnitPoint(x: 0.92, y: 1.02),
                startRadius: 40,
                endRadius: 780
            )
        }
        .ignoresSafeArea()
    }
}

struct GlassPanel: ViewModifier {
    var radius: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Theme.hairline, lineWidth: 1)
            )
    }
}

extension View {
    func glassPanel(_ radius: CGFloat = 16) -> some View {
        modifier(GlassPanel(radius: radius))
    }
}

struct ViewSwitcher: View {
    @Binding var selection: Int

    var body: some View {
        HStack(spacing: 0) {
            segment(index: 0, key: "tab.lens")
            segment(index: 1, key: "tab.bigFiles")
        }
        .padding(2)
        .background(Capsule().fill(Color.black.opacity(0.22)))
        .overlay(Capsule().stroke(Theme.hairline, lineWidth: 1))
    }

    private func segment(index: Int, key: LocalizedStringKey) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                selection = index
            }
        } label: {
            Text(key)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(selection == index ? Color.white : Theme.secondary)
                .padding(.horizontal, 14)
                .frame(height: 24)
                .background(
                    Capsule().fill(selection == index ? Color.white.opacity(0.16) : Color.clear)
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
