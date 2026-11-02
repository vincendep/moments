import SwiftUI
import SwiftData
import UIKit

@main
struct MomentsApp: App {
    init() {
        // The navigation bar is UIKit: give its titles the album's serif and ink.
        let ink = UIColor(named: "Ink") ?? .label
        let bar = UINavigationBarAppearance()
        bar.configureWithTransparentBackground()
        bar.backgroundColor = UIColor(named: "Paper")
        bar.titleTextAttributes = [.font: AlbumFont.uiDisplay(22), .foregroundColor: ink]
        bar.largeTitleTextAttributes = [.font: AlbumFont.uiDisplay(36), .foregroundColor: ink]
        UINavigationBar.appearance().standardAppearance = bar
        UINavigationBar.appearance().scrollEdgeAppearance = bar
        UINavigationBar.appearance().compactAppearance = bar
    }

    var body: some Scene {
        WindowGroup { RootView().tint(.darkroom) }
            .modelContainer(for: [Timeline.self, Entry.self])
    }
}
