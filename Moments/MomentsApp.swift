import SwiftUI
import SwiftData
import UIKit

@main
struct MomentsApp: App {
    init() {
        // The navigation bar is UIKit: give its titles the album's serif and ink.
        let ink = UIColor(named: "Ink") ?? .label
        let bar = UINavigationBarAppearance()
        // Opaque paper, no hairline: on iOS 26 a see-through bar lets prints scroll under it, and the system
        // then recolours the title and status bar for contrast (white on paper). SwiftUI's toolbarBackground
        // would also do it, but replaces this appearance and its fonts.
        bar.configureWithOpaqueBackground()
        bar.backgroundColor = UIColor(named: "Paper")
        bar.shadowColor = .clear
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
