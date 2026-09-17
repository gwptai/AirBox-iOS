import SwiftUI

struct AIView: View {
    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: AppTheme.spacingL) {
                ZStack {
                    Circle().fill(AppTheme.surface).frame(width: 96, height: 96)
                    Image(systemName: "sparkles").font(.system(size: 38, weight: .medium)).foregroundStyle(AppTheme.accentGradient)
                }
                VStack(spacing: 8) {
                    Text("AirBox AI").font(.system(size: 24, weight: .bold)).foregroundColor(AppTheme.textPrimary)
                    Text("AI-функции будут доступны здесь.").font(.system(size: 15)).foregroundColor(AppTheme.textSecondary).multilineTextAlignment(.center)
                }
            }.padding(32)
        }
        .navigationTitle("AI")
        .navigationBarTitleDisplayMode(.large)
    }
}
