import SwiftUI

struct TopBar: View {
    var title: String
    var action: String
    var onAction: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Text(title)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(PanelColor.text)
            Spacer()
            Button(action, action: onAction)
                .font(.system(size: 17))
                .foregroundStyle(PanelColor.accent)
        }
        .padding(.bottom, 8)
    }
}

struct PanelCard<Content: View>: View {
    var action: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(PanelColor.panel)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(PanelColor.line, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

struct GhostButton: View {
    var title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .foregroundStyle(PanelColor.text)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(PanelColor.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct PrimaryButton: View {
    var title: String
    var enabled: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(PanelColor.accentInk)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(enabled ? PanelColor.accent : PanelColor.accent.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

struct SettingRow: View {
    var label: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(PanelColor.muted)
            Text(value)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(PanelColor.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(PanelColor.panel)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(PanelColor.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct StatCard: View {
    var label: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(PanelColor.muted)
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(PanelColor.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(PanelColor.panel)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(PanelColor.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct ConnectControl: View {
    var phase: Phase
    var enabled: Bool
    var action: () -> Void
    @State private var spinning = false

    private var ring: Color {
        switch phase {
        case .connected: return PanelColor.online
        case .connecting: return PanelColor.accent
        case .idle: return PanelColor.line
        }
    }

    private var glyph: Color {
        switch phase {
        case .connected: return PanelColor.online
        case .connecting: return PanelColor.accent
        case .idle: return enabled ? PanelColor.text : PanelColor.muted
        }
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(PanelColor.panel)
                    .padding(4)
                Circle()
                    .stroke(ring, lineWidth: 4)
                if phase == .connecting {
                    Circle()
                        .trim(from: 0, to: 0.25)
                        .stroke(PanelColor.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(spinning ? 360 : 0))
                }
                PowerMark(color: glyph)
                    .frame(width: 54, height: 54)
            }
            .frame(width: 196, height: 196)
        }
        .buttonStyle(.plain)
        .disabled(!enabled || phase == .connecting)
        .onAppear {
            withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                spinning = true
            }
        }
    }
}

private struct PowerMark: View {
    var color: Color

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0.12, to: 0.88)
                .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Capsule()
                .fill(color)
                .frame(width: 4, height: 22)
                .offset(y: -8)
        }
    }
}
