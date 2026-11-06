import AVFoundation
import Foundation
import Testing
@testable import Moments

struct AudioTrimTests {
    /// A mono AAC recording of a tone, made like `AudioService.start` makes them.
    private func tone(seconds: Double) throws -> Data {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).m4a")
        defer { try? FileManager.default.removeItem(at: url) }
        let settings: [String: Any] = [AVFormatIDKey: kAudioFormatMPEG4AAC,
                                       AVSampleRateKey: 44_100, AVNumberOfChannelsKey: 1]
        do {
            let file = try AVAudioFile(forWriting: url, settings: settings)
            let frames = AVAudioFrameCount(seconds * 44_100)
            let buffer = try #require(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frames))
            buffer.frameLength = frames
            let samples = try #require(buffer.floatChannelData?[0])
            for i in 0..<Int(frames) { samples[i] = 0.5 * sin(Float(i) * 2 * .pi * 440 / 44_100) }
            try file.write(from: buffer)
        } // the file is finished when it's released
        return try Data(contentsOf: url)
    }

    @Test func trimKeepsOnlyTheRange() async throws {
        let data = try tone(seconds: 3)
        #expect(abs(AudioService.duration(of: data) - 3) < 0.1)
        let cut = try #require(await AudioService.trim(data, to: 1...2))
        #expect(abs(AudioService.duration(of: cut) - 1) < 0.1)
    }

    @Test func anEmptyRangeCantBeTrimmed() async throws {
        #expect(await AudioService.trim(try tone(seconds: 1), to: 0.5...0.5) == nil)
    }

    @Test func levelsAreScaledToOne() throws {
        let levels = AudioService.levels(of: try tone(seconds: 1), count: 20)
        #expect(levels.count == 20)
        #expect(levels.max() == 1)
    }
}
