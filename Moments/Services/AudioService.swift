import AVFoundation

@Observable
final class AudioService: NSObject, AVAudioPlayerDelegate {
    var isRecording = false
    var isPlaying = false
    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?

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

    func play(_ data: Data) {
        player = try? AVAudioPlayer(data: data)
        player?.delegate = self
        isPlaying = player?.play() ?? false
    }

    func stopPlaying() { player?.stop(); isPlaying = false }

    func audioPlayerDidFinishPlaying(_ p: AVAudioPlayer, successfully: Bool) { isPlaying = false }
}
