import Foundation
import Testing
@testable import Moments

@MainActor
struct EntryMediaTests {
    let store: TestStore
    let timeline: Timeline

    init() throws {
        store = try TestStore()
        timeline = store.timeline()
    }

    @Test func withoutTimeTheDateIsTheStartOfTheDay() {
        let e = Entry(timeline: timeline, date: date(2024, 5, 3, 18), hasTime: false)
        #expect(e.date == Calendar.current.startOfDay(for: date(2024, 5, 3)))
        #expect(!e.hasTime)
    }

    @Test func initNumbersTheMediaInOrder() {
        let items = [photo(), memo(), video()]
        let e = store.entry(in: timeline, media: items)
        #expect(e.sortedMedia.map(\.sortIndex) == [0, 1, 2])
        #expect(e.sortedMedia == items)
    }

    @Test func kindFollowsTheMedia() {
        #expect(store.entry(in: timeline).kind == .note)
        #expect(store.entry(in: timeline, media: [memo(), memo()]).kind == .voice)
        #expect(store.entry(in: timeline, media: [memo(), video(), photo()]).kind == .video)
        #expect(store.entry(in: timeline, media: [photo(), video()]).kind == .photo)
    }

    @Test func coverIsTheFirstPrintAfterAnyMemo() {
        let first = photo(), second = video()
        let e = store.entry(in: timeline, media: [memo(), first, memo(), second])
        #expect(e.cover == first)
        #expect(e.prints == [first, second])
        #expect(e.voiceMemos.count == 2)
    }

    @Test func addAppendsAfterTheHighestIndex() {
        let a = photo(), b = photo()
        let e = store.entry(in: timeline, media: [a, b])
        b.sortIndex = 7
        e.modifiedAt = .distantPast
        let c = memo()
        e.add(c)
        #expect(c.sortIndex == 8)
        #expect(e.sortedMedia.last == c)
        #expect(e.modifiedAt > .distantPast)
    }

    @Test func addWorksWhenMediaIsNil() {
        let e = store.entry(in: timeline)
        e.media = nil
        let p = photo()
        e.add(p)
        #expect(e.sortedMedia == [p])
        #expect(p.sortIndex == 0)
    }

    @Test func makeCoverMovesTheItemFirstAndKeepsTheRest() {
        let a = photo(), b = memo(), c = video(), d = photo()
        let e = store.entry(in: timeline, media: [a, b, c, d])
        e.makeCover(c)
        #expect(e.sortedMedia == [c, a, b, d])
        #expect(e.cover == c)
        #expect(e.kind == .video)
    }

    @Test func removeDropsTheItem() throws {
        let a = photo(), b = memo()
        let e = store.entry(in: timeline, media: [a, b])
        try store.context.save()
        e.remove(b)
        try store.context.save()
        #expect(e.sortedMedia == [a])
        #expect(try store.count(MediaItem.self) == 1)
    }

    @Test func displayTitleFallsBackToTheDate() {
        let e = store.entry(in: timeline, on: date(2009, 10, 9))
        #expect(e.displayTitle == e.dateLabel)
        e.title = "First steps"
        #expect(e.displayTitle == "First steps")
    }

    @Test func unknownMediaKindReadsAsPhoto() {
        let item = memo()
        item.kindRaw = "hologram"
        #expect(item.kind == .photo)
        #expect(item.isPrint)
    }
}
