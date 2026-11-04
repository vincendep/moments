import Foundation
import SwiftData

/// Moves the single photo, video or voice memo of entries made before entries could hold several
/// into a `MediaItem`, then clears the legacy fields (so a memo isn't stored twice in iCloud).
/// Runs at launch and whenever the app becomes active; once everything is moved it finds nothing.
enum MediaMigration {
    @MainActor static func run(in ctx: ModelContext) {
        let pending = FetchDescriptor<Entry>(predicate: #Predicate { $0.kindRaw != "" })
        guard let entries = try? ctx.fetch(pending), !entries.isEmpty else { return }
        for e in entries {
            var item: MediaItem?
            switch e.kindRaw {
            case "photo", "video":
                if e.assetLocalID != nil || e.assetCloudID != nil {
                    item = MediaItem(e.kindRaw == "video" ? .video : .photo,
                                     assetLocalID: e.assetLocalID, assetCloudID: e.assetCloudID)
                }
            case "voice":
                if let audio = e.audioData { item = MediaItem(audio: audio) }
            default:
                break
            }
            if let item {
                // The entry's own uuid, so a copy made twice (two devices before syncing) can be recognised.
                item.uuid = e.uuid
                item.sortIndex = 0
                ctx.insert(item)
                item.entry = e
            }
            e.kindRaw = ""
            e.assetLocalID = nil
            e.assetCloudID = nil
            e.audioData = nil
        }
        // One save: each entry's item and its cleared fields land together, so nothing is lost halfway.
        try? ctx.save()
    }
}
