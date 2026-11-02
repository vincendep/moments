import SwiftUI

struct VoiceRecorderView: View {
    let timeline: Timeline
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @State private var audio = AudioService()
    @State private var recording: Data?
    @State private var startedAt: Date?
    @State private var length: TimeInterval = 0
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
                if recording != nil, !audio.isRecording {
                    TitleSection(title: $title, placeholder: Entry.dateLabel(date, hasTime: hasTime))
                    DateTimeSection(date: $date, hasTime: $hasTime)
                    LocationSection(place: $place, locating: locating)
                }
            }
            .task { await locate() }
            .navigationTitle("Voice Memo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if audio.isRecording { _ = audio.stop() }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let entry = Entry(kind: .voice, timeline: timeline, date: date, hasTime: hasTime,
                                          title: title, audioData: recording, place: place)
                        Arrival.mark(entry)
                        ctx.insert(entry)
                        dismiss()
                    }
                    .disabled(recording == nil || audio.isRecording)
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
                Text(Duration.seconds(startedAt.map { context.date.timeIntervalSince($0) } ?? length),
                     format: .time(pattern: .minuteSecond))
                    .font(.timer)
            }
            if audio.isRecording {
                Text("Recording").font(.footnote).foregroundStyle(.secondary)
            } else if let recording {
                Button(audio.isPlaying ? "Stop" : "Play Back") {
                    audio.isPlaying ? audio.stopPlaying() : audio.play(recording)
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
                length = startedAt.map { Date.now.timeIntervalSince($0) } ?? 0
                startedAt = nil
            } else {
                audio.stopPlaying()
                denied = !(await audio.start())
                if !denied {
                    startedAt = .now
                    date = .now
                }
            }
        }
    }
}
