import SwiftUI

/// Records a voice memo as a new entry, or, with `adding`, as one more memo of an existing entry
/// (then without its own title, date and place).
struct VoiceRecorderView: View {
    let timeline: Timeline
    var adding: Entry? = nil
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @State private var audio = AudioService()
    @State private var recording: Data?
    @State private var startedAt: Date?
    @State private var length: TimeInterval = 0
    /// The part to keep, cut on save; nil while there's nothing to trim.
    @State private var trim: ClosedRange<TimeInterval>?
    @State private var saving = false
    @State private var title = ""
    @State private var date = Date.now
    @State private var hasTime = true
    @State private var denied = false
    @State private var place: Place?
    @State private var locating = LocationService.isAuthorized

    var body: some View {
        NavigationStack {
            PaperForm {
                Section { recorder.frame(maxWidth: .infinity).padding(.vertical, 24) }
                if adding == nil, recording != nil, !audio.isRecording {
                    TitleSection(title: $title, placeholder: Entry.dateLabel(date, hasTime: hasTime))
                    WhenWhereSection(date: $date, hasTime: $hasTime, place: $place, locating: locating)
                }
            }
            .task { if adding == nil { await locate() } }
            .navigationTitle(adding == nil ? Text("Voice Memo") : Text("Add Voice Memo"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if audio.isRecording { _ = audio.stop() }
                        audio.stopPlaying()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(recording == nil || audio.isRecording || saving)
                }
            }
        }
    }

    /// The record button, the running time, and what to do next.
    private var recorder: some View {
        VStack(spacing: 8) {
            CassetteView(title: title.isEmpty ? String(localized: "Voice Memo") : title, spinning: audio.isRecording)
                .padding(.bottom, 8)
            Button(action: toggleRecording) {
                Image(systemName: audio.isRecording ? "stop.fill" : "mic.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse, isActive: audio.isRecording)
                    .frame(width: 96, height: 96)
                    .background(Circle().fill(audio.isRecording ? Color.red : Color.darkroomFill))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(audio.isRecording ? "Stop Recording" : recording == nil ? "Record" : "Record Again")
            // The app's own TimelineView shadows SwiftUI's.
            SwiftUI.TimelineView(.periodic(from: .now, by: 0.5)) { context in
                Text(Duration.seconds(startedAt.map { context.date.timeIntervalSince($0) } ?? kept),
                     format: .time(pattern: .minuteSecond))
                    .font(.timer)
            }
            if audio.isRecording {
                Text("Recording").font(.footnote).foregroundStyle(.secondary)
            } else if let recording {
                if let trim {
                    SwiftUI.TimelineView(.animation(paused: !audio.isPlaying)) { _ in
                        AudioTrimmer(data: recording, duration: length,
                                     range: Binding { trim } set: { self.trim = $0 },
                                     playhead: audio.isPlaying ? audio.currentTime : nil)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .onChange(of: trim) { audio.stopPlaying() }
                }
                Button(audio.isPlaying ? "Stop" : "Play Back") {
                    audio.isPlaying ? audio.stopPlaying() : audio.play(recording, range: trim)
                }
                .buttonStyle(.borderless)
            } else if denied {
                // start() also fails without a usable input (the simulator); the button stays for a retry.
                Text("Microphone access denied. Enable it in Settings.")
                    .font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center)
            } else {
                Text("Tap to record").font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    /// How long the memo will be once trimmed.
    private var kept: TimeInterval { trim.map { $0.upperBound - $0.lowerBound } ?? length }

    /// Cuts the recording to the trimmed part (keeping it whole if that fails) and saves it.
    private func save() async {
        guard var data = recording else { return }
        saving = true
        audio.stopPlaying()
        if let trim, trim.lowerBound > 0.05 || trim.upperBound < length - 0.05,
           let cut = await AudioService.trim(data, to: trim) {
            data = cut
        }
        if let adding {
            adding.add(MediaItem(audio: data))
        } else {
            let entry = Entry(timeline: timeline, date: date, hasTime: hasTime, title: title,
                              media: [MediaItem(audio: data)], place: place)
            Arrival.mark(entry)
            ctx.insert(entry)
        }
        dismiss()
    }

    /// Fills in the current location, unless one was picked meanwhile.
    private func locate() async {
        let current = await LocationService.current()
        if place == nil { place = current }
        locating = false
    }

    private func toggleRecording() {
        Task {
            if audio.isRecording {
                recording = audio.stop()
                let measured = recording.map(AudioService.duration(of:)) ?? 0
                length = measured > 0 ? measured : startedAt.map { Date.now.timeIntervalSince($0) } ?? 0
                startedAt = nil
                // Too short to be worth trimming.
                trim = length >= 2 * AudioTrimmer.minimum ? 0...length : nil
            } else {
                audio.stopPlaying()
                trim = nil
                denied = !(await audio.start())
                if !denied {
                    startedAt = .now
                    date = .now
                }
            }
        }
    }
}
