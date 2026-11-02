import Foundation
import SwiftData

@Model
final class Timeline {
    /// Stable ID for remembering the last opened timeline across launches.
    var uuid: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()
    /// Which Photos album new media goes into; see `AlbumMode`.
    var albumModeRaw: String = AlbumMode.perTimeline.rawValue
    /// Whether assets picked from the library are also added to that album.
    var addImportsToAlbum: Bool = true
    @Relationship(deleteRule: .cascade, inverse: \Entry.timeline) var entries: [Entry]? = []

    init(name: String) {
        self.name = name
    }

    var albumMode: AlbumMode {
        get { AlbumMode(rawValue: albumModeRaw) ?? .perTimeline }
        set { albumModeRaw = newValue.rawValue }
    }

    var sortedEntries: [Entry] { (entries ?? []).sorted { $0.date > $1.date } }
}
