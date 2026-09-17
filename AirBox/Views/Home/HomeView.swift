import SwiftUI
import UIKit

struct HomeView: View {
    init() {
        configureTabBarAppearance()
        configureNavigationBarAppearance()
    }

    var body: some View {
        TabView {
            NavigationStack { VideoListView() }
                .tabItem { Label("Видео", systemImage: "film.stack.fill") }
            NavigationStack { MusicView() }
                .tabItem { Label("Музыка", systemImage: "music.note") }
            NavigationStack { AIView() }
                .tabItem { Label("AI", systemImage: "cpu") }
            NavigationStack { FilesView() }
                .tabItem { Label("Файлы", systemImage: "folder.fill") }
        }
        .tint(AppTheme.accent)
    }

    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 0.05, green: 0.05, blue: 0.058, alpha: 0.98)
        appearance.shadowColor = UIColor.white.withAlphaComponent(0.06)
        let normal = UIColor.white.withAlphaComponent(0.42)
        let selected = UIColor(red: 0.40, green: 0.68, blue: 1.0, alpha: 1)
        for layout in [appearance.stackedLayoutAppearance, appearance.inlineLayoutAppearance, appearance.compactInlineLayoutAppearance] {
            layout.normal.iconColor = normal
            layout.normal.titleTextAttributes = [.foregroundColor: normal, .font: UIFont.systemFont(ofSize: 10, weight: .medium)]
            layout.selected.iconColor = selected
            layout.selected.titleTextAttributes = [.foregroundColor: selected, .font: UIFont.systemFont(ofSize: 10, weight: .semibold)]
        }
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    private func configureNavigationBarAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 0.043, green: 0.043, blue: 0.047, alpha: 1)
        appearance.shadowColor = .clear
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white, .font: UIFont.systemFont(ofSize: 32, weight: .bold)]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().tintColor = .white
    }
}
