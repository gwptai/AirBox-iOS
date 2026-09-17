import SwiftUI

struct MusicView: View {

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 64))
                    .foregroundColor(.gray)

                Text("Музыка")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                Text("Импорт и воспроизведение\nбудут добавлены на следующем этапе")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
        }
        .navigationTitle("Музыка")
        .navigationBarTitleDisplayMode(.large)
    }
}