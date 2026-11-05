import Foundation
import Testing
@testable import Moments

@MainActor
struct TimelineTests {
    let store: TestStore
    let timeline: Timeline

    init() throws {
        store = try TestStore()
        timeline = store.timeline()
    }

    @Test func albumModeMapsToItsRawValue() {
        timeline.albumMode = .shared
        #expect(timeline.albumModeRaw == "shared")
        timeline.albumModeRaw = "none"
        #expect(timeline.albumMode == AlbumMode.none)
        timeline.albumModeRaw = "unknown"
        #expect(timeline.albumMode == .perTimeline)
    }

    @Test func deletingATimelineDeletesItsEntriesAndMedia() throws {
        store.entry(in: timeline, media: [photo(), memo()])
        store.entry(in: timeline)
        try store.context.save()
        store.context.delete(timeline)
        try store.context.save()
        #expect(try store.count(Timeline.self) == 0)
        #expect(try store.count(Entry.self) == 0)
        #expect(try store.count(MediaItem.self) == 0)
    }

    @Test func entriesAreGroupedByMonthNewestFirst() {
        let mayLate = store.entry(in: timeline, on: date(2024, 5, 30))
        let mayEarly = store.entry(in: timeline, on: date(2024, 5, 2))
        let march = store.entry(in: timeline, on: date(2024, 3, 9))
        let lastYear = store.entry(in: timeline, on: date(2023, 5, 15))
        let groups = timeline.entriesByMonth
        #expect(groups.map(\.0) == [date(2024, 5, 1, 0), date(2024, 3, 1, 0), date(2023, 5, 1, 0)])
        #expect(groups.map(\.1) == [[mayLate, mayEarly], [march], [lastYear]])
    }

    @Test func oneScrubberDayPerDayFlaggedByAnyMilestone() throws {
        let evening = store.entry(in: timeline, on: date(2024, 5, 2, 20))
        store.entry(in: timeline, on: date(2024, 5, 2, 8), milestone: true)
        let other = store.entry(in: timeline, on: date(2024, 4, 1))
        let days = timeline.scrubberDays
        #expect(days.map(\.date) == [date(2024, 5, 2, 0), date(2024, 4, 1, 0)])
        #expect(days.map(\.isMilestone) == [true, false])
        // Each day points at its first row, the newest entry that day.
        #expect(days.map(\.entryID) == [evening.id, other.id])
    }

    @Test func emptyTimelineHasNoGroups() {
        #expect(timeline.entriesByMonth.isEmpty)
        #expect(timeline.scrubberDays.isEmpty)
        #expect(timeline.milestones.isEmpty)
    }
}
