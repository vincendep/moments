import Foundation
import SwiftData

enum EntryKind: String, Codable, CaseIterable {
    case photo, video, note, voice
    /// The kind's custom icon in the asset catalog.
    var icon: String {
        switch self {
        case .photo: "icon.library"
        case .video: "icon.camera"
        case .note: "icon.note"
        case .voice: "icon.voice"
        }
    }
}

@Model
final class Entry {
    /// Stable identity across devices and exports (for merging timelines).
    var uuid: UUID = UUID()
    /// Last edit, so a later merge can keep the newer copy.
    var modifiedAt: Date = Date()
    var date: Date = Date()
    /// When false, only the day matters and `date` is stored at the start of that day.
    var hasTime: Bool = true
    var kindRaw: String = EntryKind.note.rawValue
    /// Optional; `displayTitle` falls back to the date.
    var title: String = ""
    /// The entry's notes (the whole content for note entries).
    var text: String = ""
    /// Shown on the milestones view's line; see `Models/Milestones.swift`.
    var isMilestone: Bool = false
    /// The asset in Photos on the device that added it (no duplication). Other devices resolve
    /// the asset through `assetCloudID`; see `PhotoService.localID(for:)`.
    var assetLocalID: String?
    /// iCloud Photos identifier of the asset, the same on every device.
    var assetCloudID: String?
    /// Voice memo audio, stored next to the database and synced with it.
    @Attribute(.externalStorage) var audioData: Data?
    /// Where it happened, nil for none. Read and set together through `place` (`Models/Place.swift`).
    var latitude: Double?
    var longitude: Double?
    var placeName: String = ""
    var timeline: Timeline?

    var kind: EntryKind { EntryKind(rawValue: kindRaw) ?? .note }

    /// The title, or the date (with the time when set) for untitled entries.
    var displayTitle: String { title.isEmpty ? dateLabel : title }

    /// e.g. "9 Oct 2009, 23:09", or "9 Oct 2009" without a time.
    var dateLabel: String { Self.dateLabel(date, hasTime: hasTime) }

    static func dateLabel(_ date: Date, hasTime: Bool) -> String {
        date.formatted(date: .abbreviated, time: hasTime ? .shortened : .omitted)
    }

    /// The date line in a timeline row, e.g. "Wed 8 · 23:55". No month or year: the month header shows them.
    var rowDateLabel: String {
        let day = date.formatted(.dateTime.weekday(.abbreviated).day())
        return hasTime ? "\(day) · \(date.formatted(date: .omitted, time: .shortened))" : day
    }

    init(kind: EntryKind, timeline: Timeline, date: Date = .now, hasTime: Bool = true,
         title: String = "", text: String = "",
         assetLocalID: String? = nil, assetCloudID: String? = nil, audioData: Data? = nil,
         place: Place? = nil) {
        self.kindRaw = kind.rawValue
        self.timeline = timeline
        self.date = hasTime ? date : Calendar.current.startOfDay(for: date)
        self.hasTime = hasTime
        self.title = title
        self.text = text
        self.assetLocalID = assetLocalID
        self.assetCloudID = assetCloudID
        self.audioData = audioData
        self.place = place
    }
}
