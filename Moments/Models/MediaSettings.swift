import Foundation

/// How a timeline's captured and imported media is organised into Photos albums.
enum AlbumMode: String, CaseIterable, Identifiable {
    case perTimeline, shared, none
    var id: Self { self }
    var title: String {
        switch self {
        case .perTimeline: String(localized: "Its own album")
        case .shared: String(localized: "Shared \"\(PhotoService.sharedAlbumName)\" album")
        case .none: String(localized: "No album")
        }
    }
}
