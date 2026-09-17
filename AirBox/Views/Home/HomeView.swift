import SwiftUI
import UIKit

struct HomeView: View {

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .black

        appearance.stackedLayoutAppearance.normal.iconColor = .gray
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.gray
        ]

        appearance.stackedLayoutAppearance.selected.iconColor = .white
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor.white
        ]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView {
            NavigationStack {
                VideoListView()
            }
            .tabItem {
                Label("Видео", systemImage: "film.stack.fill")
            }

            NavigationStack {
                MusicView()
            }
            .tabItem {
                Label("Музыка", systemImage: "music.note")
            }

            NavigationStack {
                AIView()
            }
            .tabItem {
                Label("AI", systemImage: "cpu")
            }

            NavigationStack {
                FilesView()
            }
            .tabItem {
                Label("Файлы", systemImage: "folder.fill")
            }
        }
        .tint(.white)
    }
}