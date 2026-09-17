import SwiftUI

struct AIView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "sparkles")
                    .font(.system(size: 44))

                Text("AirBox AI")
                    .font(.title2.weight(.semibold))

                Text("AI-функции будут доступны здесь.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("AI")
        }
    }
}

#Preview {
    AIView()
}
