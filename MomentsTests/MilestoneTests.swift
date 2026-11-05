import Foundation
import Testing
@testable import Moments

@MainActor
struct MilestoneTests {
    let store: TestStore
    let timeline: Timeline

    init() throws {
        store = try TestStore()
        timeline = store.timeline()
    }

    @Test func milestonesAreOnlyMilestonesOldestFirst() {
        let late = store.entry(in: timeline, on: date(2024, 6, 1), milestone: true)
        let plain = store.entry(in: timeline, on: date(2023, 1, 1))
        let early = store.entry(in: timeline, on: date(2022, 3, 4), milestone: true)
        #expect(timeline.milestones == [early, late])
        #expect(timeline.sortedEntries == [late, plain, early])
    }

    @Test func intervalOnTheSameDay() {
        let a = store.entry(in: timeline, on: date(2024, 6, 1, 9))
        let b = store.entry(in: timeline, on: date(2024, 6, 1, 20))
        #expect(b.interval(since: a) == "Same day")
        #expect(b.sinceFirstMilestone(a) == "Same day")
    }

    @Test func sinceFirstMilestone() {
        let first = store.entry(in: timeline, on: date(2022, 3, 4), milestone: true)
        let later = store.entry(in: timeline, on: date(2024, 6, 4), milestone: true)
        #expect(first.sinceFirstMilestone(first) == "Start")
        #expect(later.sinceFirstMilestone(first) == "2 years, 3 months")
        #expect(later.interval(since: first) == "2 years, 3 months")
    }

    @Test(arguments: [
        (date(2024, 1, 4), "3 days"),
        (date(2024, 1, 15), "2 weeks"),
        (date(2024, 6, 15), "5 months, 2 weeks"),
        (date(2026, 4, 20), "2 years, 3 months"),
        (date(2025, 1, 1), "1 year"),
    ])
    func elapsed(to end: Date, expected: String) {
        #expect(Elapsed.string(from: date(2024, 1, 1), to: end) == expected)
    }

    @Test func elapsedIsNilOnTheSameDay() {
        #expect(Elapsed.string(from: date(2024, 1, 1, 8), to: date(2024, 1, 1, 22)) == nil)
    }
}
