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
    /// Optional; `displayTitle` falls back to the date.
    var title: String = ""
    /// The entry's notes (the whole content for note entries).
    var text: String = ""
    /// Shown on the milestones view's line; see `Models/Milestones.swift`.
    var isMilestone: Bool = false
    /// The entry's photos, videos and voice memos, in no particular order; read them through `sortedMedia`.
    @Relationship(deleteRule: .cascade, inverse: \MediaItem.entry) var media: [MediaItem]? = []
    /// Where it happened, nil for none. Read and set together through `place` (`Models/Place.swift`).
    var latitude: Double?
    var longitude: Double?
    var placeName: String = ""
    var timeline: Timeline?

    // Legacy: an entry used to hold one photo, video or voice memo. Read only by `MediaMigration`, which
    // moves them into a `MediaItem` and clears them; kept (with their names) so the synced data can be read.
    // `kindRaw` is "" once migrated, and for every entry created since.
    var kindRaw: String = ""
    var assetLocalID: String?
    var assetCloudID: String?
    @Attribute(.externalStorage) var audioData: Data?

    /// How the entry is shown: a print when it has a photo or video (the cover's kind), a cassette when it
    /// only has voice memos, a letter when it has neither.
    var kind: EntryKind {
        if let cover { return cover.kind == .video ? .video : .photo }
        return voiceMemos.isEmpty ? .note : .voice
    }

    /// The media in order.
    var sortedMedia: [MediaItem] {
        (media ?? []).sorted { ($0.sortIndex, $0.uuid.uuidString) < ($1.sortIndex, $1.uuid.uuidString) }
    }

    /// Photos and videos, in order.
    var prints: [MediaItem] { sortedMedia.filter(\.isPrint) }

    var voiceMemos: [MediaItem] { sortedMedia.filter { $0.kind == .voice } }

    /// The first print: the one shown in the timeline.
    var cover: MediaItem? { sortedMedia.first(where: \.isPrint) }

    /// Adds a photo, video or voice memo after the others.
    func add(_ item: MediaItem) {
        item.sortIndex = ((media ?? []).map(\.sortIndex).max() ?? -1) + 1
        if media == nil { media = [] }
        media?.append(item)
        modifiedAt = .now
    }

    /// Removes a photo, video or voice memo. Photos and videos stay in Photos; a voice memo is gone.
    func remove(_ item: MediaItem) {
        media?.removeAll { $0 == item }
        modelContext?.delete(item)
        modifiedAt = .now
    }

    /// Makes a print the cover, keeping the order of the rest.
    func makeCover(_ item: MediaItem) {
        for (i, m) in ([item] + sortedMedia.filter { $0 != item }).enumerated() { m.sortIndex = i }
        modifiedAt = .now
    }

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

    init(timeline: Timeline, date: Date = .now, hasTime: Bool = true, title: String = "", text: String = "",
         media: [MediaItem] = [], place: Place? = nil) {
        self.timeline = timeline
        self.date = hasTime ? date : Calendar.current.startOfDay(for: date)
        self.hasTime = hasTime
        self.title = title
        self.text = text
        for (i, item) in media.enumerated() { item.sortIndex = i }
        self.media = media
        self.place = place
    }
}
