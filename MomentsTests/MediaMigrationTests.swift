import Foundation
import Testing
@testable import Moments

@MainActor
struct MediaMigrationTests {
    let store: TestStore
    let timeline: Timeline

    init() throws {
        store = try TestStore()
        timeline = store.timeline()
    }

    /// An entry in the old single-media form.
    private func legacy(_ kind: String, local: String? = nil, cloud: String? = nil, audio: Data? = nil) -> Entry {
        let e = store.entry(in: timeline)
        e.kindRaw = kind
        e.assetLocalID = local
        e.assetCloudID = cloud
        e.audioData = audio
        return e
    }

    private func expectCleared(_ e: Entry) {
        #expect(e.kindRaw == "")
        #expect(e.assetLocalID == nil)
        #expect(e.assetCloudID == nil)
        #expect(e.audioData == nil)
    }

    @Test(arguments: [("photo", MediaKind.photo), ("video", MediaKind.video)])
    func printBecomesAMediaItem(raw: String, kind: MediaKind) throws {
        let e = legacy(raw, local: "L1", cloud: "C1")
        MediaMigration.run(in: store.context)
        let item = try #require(e.sortedMedia.first)
        #expect(e.sortedMedia.count == 1)
        #expect(item.kind == kind)
        #expect(item.assetLocalID == "L1")
        #expect(item.assetCloudID == "C1")
        #expect(item.uuid == e.uuid)
        #expect(item.sortIndex == 0)
        expectCleared(e)
    }

    @Test func voiceMemoKeepsItsAudio() throws {
        let audio = Data("memo".utf8)
        let e = legacy("voice", audio: audio)
        MediaMigration.run(in: store.context)
        let item = try #require(e.sortedMedia.first)
        #expect(item.kind == .voice)
        #expect(item.audioData == audio)
        #expect(e.kind == .voice)
        expectCleared(e)
    }

    @Test func entriesWithNothingToMoveAreOnlyCleared() throws {
        let photoWithoutIDs = legacy("photo")
        let voiceWithoutAudio = legacy("voice")
        MediaMigration.run(in: store.context)
        #expect(try store.count(MediaItem.self) == 0)
        expectCleared(photoWithoutIDs)
        expectCleared(voiceWithoutAudio)
        #expect(photoWithoutIDs.kind == .note)
    }

    @Test func runningAgainChangesNothing() throws {
        legacy("photo", local: "L1", cloud: "C1")
        legacy("voice", audio: Data([0]))
        MediaMigration.run(in: store.context)
        MediaMigration.run(in: store.context)
        #expect(try store.count(MediaItem.self) == 2)
    }

    @Test func newEntriesAreLeftAlone() throws {
        let p = photo()
        let e = store.entry(in: timeline, media: [p])
        MediaMigration.run(in: store.context)
        #expect(e.sortedMedia == [p])
        #expect(try store.count(MediaItem.self) == 1)
    }
}
