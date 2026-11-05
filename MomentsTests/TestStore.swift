import Foundation
import SwiftData
@testable import Moments

/// A fresh in-memory store per test, with no CloudKit, and helpers to fill it.
@MainActor
struct TestStore {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(for: Timeline.self, Entry.self, MediaItem.self, configurations: config)
    }

    func timeline(_ name: String = "Test") -> Timeline {
        let t = Timeline(name: name)
        context.insert(t)
        return t
    }

    @discardableResult
    func entry(in timeline: Timeline, on date: Date = .now, milestone: Bool = false, media: [MediaItem] = []) -> Entry {
        let e = Entry(timeline: timeline, date: date, media: media)
        e.isMilestone = milestone
        context.insert(e)
        return e
    }

    func count<T: PersistentModel>(_ type: T.Type) throws -> Int {
        try context.fetchCount(FetchDescriptor<T>())
    }
}

/// A photo with both IDs given, so `MediaItem.init` doesn't ask Photos for the iCloud one.
func photo(_ id: String = UUID().uuidString) -> MediaItem { MediaItem(.photo, assetLocalID: id, assetCloudID: "cloud-\(id)") }
func video(_ id: String = UUID().uuidString) -> MediaItem { MediaItem(.video, assetLocalID: id, assetCloudID: "cloud-\(id)") }
func memo() -> MediaItem { MediaItem(audio: Data([1, 2, 3])) }

/// A date in the current calendar, at noon unless an hour is given.
func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
    Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
}
