import SwiftUI

/// Единая дизайн-система AirBox.
enum AppTheme {
    static let background = Color(red: 0.043, green: 0.043, blue: 0.047)
    static let backgroundSecondary = Color(red: 0.078, green: 0.082, blue: 0.09)
    static let surface = Color.white.opacity(0.06)
    static let surfaceElevated = Color.white.opacity(0.10)
    static let stroke = Color.white.opacity(0.08)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.6)
    static let textTertiary = Color.white.opacity(0.38)
    static let accentStart = Color(red: 0.36, green: 0.56, blue: 1.0)
    static let accentEnd = Color(red: 0.42, green: 0.83, blue: 1.0)
    static let accent = Color(red: 0.40, green: 0.68, blue: 1.0)
    static let accentGradient = LinearGradient(colors: [accentStart, accentEnd], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let danger = Color(red: 1.0, green: 0.36, blue: 0.36)
    static let radiusS: CGFloat = 10
    static let radiusM: CGFloat = 16
    static let radiusL: CGFloat = 22
    static let radiusXL: CGFloat = 28
    static let spacingXS: CGFloat = 4
    static let spacingS: CGFloat = 8
    static let spacingM: CGFloat = 12
    static let spacingL: CGFloat = 16
    static let spacingXL: CGFloat = 24
}

struct AppBackground: View {
    var body: some View {
        LinearGradient(colors: [AppTheme.backgroundSecondary, AppTheme.background], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }
}

struct ScaledButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension View {
    func cardStyle(padding: CGFloat = AppTheme.spacingM, radius: CGFloat = AppTheme.radiusM) -> some View {
        self.padding(padding)
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(AppTheme.surface))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(AppTheme.stroke, lineWidth: 1))
    }
}

struct GradientImportButton: View {
    let title: String
    var systemImage: String = "plus"
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage).font(.system(size: 15, weight: .semibold))
                Text(title).font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(.black)
            .padding(.horizontal, 22).padding(.vertical, 14)
            .background(AppTheme.accentGradient).clipShape(Capsule())
            .shadow(color: AppTheme.accentStart.opacity(0.35), radius: 16, x: 0, y: 8)
        }.buttonStyle(ScaledButtonStyle())
    }
}

struct CircleIconButton: View {
    let systemImage: String
    var size: CGFloat = 32
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundColor(.black)
                .frame(width: size, height: size)
                .background(AppTheme.accentGradient).clipShape(Circle())
        }.buttonStyle(ScaledButtonStyle())
    }
}

struct InfoChip: View {
    let icon: String
    let text: String
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 10, weight: .semibold))
            Text(text).font(.system(size: 12, weight: .medium))
        }
        .foregroundColor(AppTheme.textSecondary)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(AppTheme.surfaceElevated).clipShape(Capsule())
    }
}

struct MediaThumbnail: View {
    let systemImage: String
    var size: CGFloat = 52
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppTheme.radiusS, style: .continuous).fill(AppTheme.accentGradient.opacity(0.16))
            Image(systemName: systemImage).font(.system(size: size * 0.4, weight: .medium)).foregroundStyle(AppTheme.accentGradient)
        }.frame(width: size, height: size)
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle().fill(AppTheme.surface).frame(width: 96, height: 96)
                Image(systemName: icon).font(.system(size: 36, weight: .medium)).foregroundStyle(AppTheme.accentGradient)
            }
            VStack(spacing: 6) {
                Text(title).font(.system(size: 19, weight: .semibold)).foregroundColor(.white)
                Text(subtitle).font(.system(size: 14)).foregroundColor(AppTheme.textSecondary).multilineTextAlignment(.center)
            }
            if let actionTitle, let action {
                GradientImportButton(title: actionTitle, action: action).padding(.top, 6)
            }
        }.padding(.horizontal, 32).frame(maxWidth: .infinity)
    }
}

struct LoadingOverlay: View {
    let text: String
    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView().tint(.white).scaleEffect(1.2)
                Text(text).font(.system(size: 14, weight: .medium)).foregroundColor(.white)
            }
            .padding(28)
            .background(RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous).fill(.ultraThinMaterial))
        }.transition(.opacity)
    }
}
