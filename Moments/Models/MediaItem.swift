import Foundation
import SwiftData

enum MediaKind: String, Codable {
    case photo, video, voice
}

/// One photo, video or voice memo of an entry. An entry holds any mix of them, in `sortIndex` order.
@Model
final class MediaItem {
    var uuid: UUID = UUID()
    var kindRaw: String = MediaKind.photo.rawValue
    /// Order within the entry (CloudKit has no ordered relationships); the first print is the cover.
    var sortIndex: Int = 0
    /// Photos and videos: the asset in Photos on the device that added it (no duplication). Other devices
    /// resolve it through `assetCloudID`; see `PhotoService.localID(for:)`.
    var assetLocalID: String?
    /// iCloud Photos identifier of the asset, the same on every device.
    var assetCloudID: String?
    /// Voice memos: the audio, stored next to the database and synced with it.
    @Attribute(.externalStorage) var audioData: Data?
    var entry: Entry?

    var kind: MediaKind { MediaKind(rawValue: kindRaw) ?? .photo }

    /// A photo or a video: shown as a print.
    var isPrint: Bool { kind != .voice }

    /// A photo or video in Photos.
    init(_ kind: MediaKind, assetLocalID: String?, assetCloudID: String? = nil) {
        self.kindRaw = kind.rawValue
        self.assetLocalID = assetLocalID
        self.assetCloudID = assetCloudID ?? assetLocalID.flatMap(PhotoService.cloudID(forLocalID:))
    }

    /// A voice memo.
    init(audio: Data) {
        self.kindRaw = MediaKind.voice.rawValue
        self.audioData = audio
    }
}
