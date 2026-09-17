import SwiftUI

struct FilesView: View {

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.gray)

                Text("Файлы")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                Text("Импорт и управление файлами\nбудут добавлены на следующем этапе")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
        }
        .navigationTitle("Файлы")
        .navigationBarTitleDisplayMode(.large)
    }
}