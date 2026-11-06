import AVFoundation

@Observable
final class AudioService: NSObject, AVAudioPlayerDelegate {
    var isRecording = false
    var isPlaying = false
    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private var stopAtEnd: DispatchWorkItem?

    /// Where playback is, in seconds from the start of the recording.
    var currentTime: TimeInterval { player?.currentTime ?? 0 }

    func start() async -> Bool {
        guard await AVAudioApplication.requestRecordPermission() else { return false }
        let s = AVAudioSession.sharedInstance()
        try? s.setCategory(.playAndRecord, mode: .default, options: .defaultToSpeaker)
        try? s.setActive(true)
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).m4a")
        let settings: [String: Any] = [AVFormatIDKey: kAudioFormatMPEG4AAC,
                                       AVSampleRateKey: 44_100, AVNumberOfChannelsKey: 1]
        recorder = try? AVAudioRecorder(url: url, settings: settings)
        isRecording = recorder?.record() ?? false
        return isRecording
    }

    /// Returns the recording; the temporary file is removed (the entry stores the data).
    func stop() -> Data? {
        recorder?.stop()
        isRecording = false
        guard let url = recorder?.url else { return nil }
        defer { try? FileManager.default.removeItem(at: url) }
        return try? Data(contentsOf: url)
    }

    /// Plays the recording, or only `range` of it.
    func play(_ data: Data, range: ClosedRange<TimeInterval>? = nil) {
        stopAtEnd?.cancel()
        player = try? AVAudioPlayer(data: data)
        player?.delegate = self
        if let range { player?.currentTime = range.lowerBound }
        isPlaying = player?.play() ?? false
        if isPlaying, let range {
            let work = DispatchWorkItem { [weak self] in self?.stopPlaying() }
            stopAtEnd = work
            DispatchQueue.main.asyncAfter(deadline: .now() + range.upperBound - range.lowerBound, execute: work)
        }
    }

    func stopPlaying() {
        stopAtEnd?.cancel()
        stopAtEnd = nil
        player?.stop()
        isPlaying = false
    }

    func audioPlayerDidFinishPlaying(_ p: AVAudioPlayer, successfully: Bool) { isPlaying = false }

    /// The length of a recording in seconds (0 if it can't be read).
    static func duration(of data: Data) -> TimeInterval {
        (try? AVAudioPlayer(data: data))?.duration ?? 0
    }

    /// The recording cut down to `range` (in seconds), or nil if it can't be cut.
    static func trim(_ data: Data, to range: ClosedRange<TimeInterval>) async -> Data? {
        guard range.lowerBound >= 0, range.upperBound > range.lowerBound else { return nil }
        let input = temporaryFile(), output = temporaryFile()
        defer {
            try? FileManager.default.removeItem(at: input)
            try? FileManager.default.removeItem(at: output)
        }
        guard (try? data.write(to: input)) != nil,
              let export = AVAssetExportSession(asset: AVURLAsset(url: input),
                                                presetName: AVAssetExportPresetAppleM4A) else { return nil }
        export.outputURL = output
        export.outputFileType = .m4a
        export.timeRange = CMTimeRange(start: CMTime(seconds: range.lowerBound, preferredTimescale: 600),
                                       end: CMTime(seconds: range.upperBound, preferredTimescale: 600))
        await export.export()
        guard export.status == .completed else { return nil }
        return try? Data(contentsOf: output)
    }

    /// Peak levels of `count` equal slices of the recording, scaled to 0...1, for drawing a waveform.
    static func levels(of data: Data, count: Int) -> [Float] {
        let url = temporaryFile()
        defer { try? FileManager.default.removeItem(at: url) }
        guard count > 0, (try? data.write(to: url)) != nil,
              let file = try? AVAudioFile(forReading: url), file.length > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                            frameCapacity: AVAudioFrameCount(max(1, file.length / Int64(count))))
        else { return [] }
        var peaks: [Float] = []
        while peaks.count < count, (try? file.read(into: buffer)) != nil, buffer.frameLength > 0,
              let samples = buffer.floatChannelData?[0] {
            var peak: Float = 0
            for i in 0..<Int(buffer.frameLength) { peak = max(peak, abs(samples[i])) }
            peaks.append(peak)
        }
        let top = peaks.max() ?? 0
        return top > 0 ? peaks.map { $0 / top } : peaks
    }

    private static func temporaryFile() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).m4a")
    }
}
