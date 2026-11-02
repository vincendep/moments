import SwiftUI
import AVKit

/// Shows an entry's media (a taped-in print, or a cassette for voice memos) and edits its title,
/// notes, date and location in place.
struct EntryDetailView: View {
    @Bindable var entry: Entry
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    @State private var player: AVPlayer?
    @State private var audio = AudioService()
    @State private var confirmDelete = false
    /// Flipped on appear to flicker the date stamp on, like an old LCD.
    @State private var stampFlicker = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        PaperForm {
            if entry.kind != .note {
                Section { media }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            TitleSection(title: $entry.title, placeholder: entry.dateLabel)
            NotesSection(text: $entry.text, minHeight: 120)
            DateTimeSection(date: $entry.date, hasTime: $entry.hasTime)
            LocationSection(place: $entry.place, date: entry.date)
            Section {
                Button("Delete Entry", role: .destructive) { confirmDelete = true }
                    .frame(maxWidth: .infinity)
                    .confirmationDialog("Delete this entry?", isPresented: $confirmDelete,
                                        titleVisibility: .visible) {
                        Button("Delete Entry", role: .destructive, action: delete)
                    } message: {
                        Text(entry.kind == .photo || entry.kind == .video
                             ? "The photo or video stays in your Photos library."
                             : "This can't be undone.")
                    }
            }
        }
        .navigationTitle(entry.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                // The ribbon: outlined in red, filled in marigold (the milestone mark) when it is one.
                // Marking drops it in from above.
                Button {
                    entry.isMilestone.toggle()
                } label: {
                    Label { Text("Milestone") } icon: {
                        Image(entry.isMilestone ? "icon.ribbon.fill" : "icon.ribbon")
                    }
                    .keyframeAnimator(initialValue: CGFloat(0), trigger: entry.isMilestone) { label, y in
                        label.offset(y: y)
                    } keyframes: { _ in
                        LinearKeyframe(ribbonDrop, duration: 0.01)
                        SpringKeyframe(0, duration: 0.4, spring: .bouncy)
                    }
                }
                .tint(entry.isMilestone ? Color.marigold : Color.darkroom)
                .accessibilityAddTraits(entry.isMilestone ? .isSelected : [])
                .sensoryFeedback(.impact(weight: .light), trigger: entry.isMilestone)
            }
        }
        .task(id: entry.assetLocalID) { await loadMedia() }
        .onDisappear {
            player?.pause()
            audio.stopPlaying()
            if !entry.isDeleted {
                if entry.hasChanges { entry.modifiedAt = .now }
                try? ctx.save()
            }
        }
    }

    /// How far the ribbon drops in from when marking a milestone (none when unmarking or with Reduce Motion).
    private var ribbonDrop: CGFloat { entry.isMilestone && !reduceMotion ? -14 : 0 }

    @ViewBuilder private var media: some View {
        switch entry.kind {
        case .photo:
            if let image {
                taped(Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 440))
            } else {
                taped(placeholder)
            }
        case .video:
            if let player {
                taped(VideoPlayer(player: player).frame(height: 300))
            } else {
                taped(placeholder)
            }
        case .voice:
            VStack(spacing: 16) {
                CassetteView(title: entry.displayTitle, spinning: audio.isPlaying)
                Button {
                    guard let data = entry.audioData else { return }
                    audio.isPlaying ? audio.stopPlaying() : audio.play(data)
                } label: {
                    Label {
                        Text(audio.isPlaying ? "Stop" : "Play Voice Memo")
                    } icon: {
                        if audio.isPlaying { Image(systemName: "stop.fill") } else { Image("icon.play") }
                    }
                    .font(.headline)
                    .padding(.horizontal, 20)
                    .frame(minHeight: 44)
                    .overlay(Capsule().strokeBorder(Color.darkroom, lineWidth: 1.5))
                }
                .buttonStyle(.borderless)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        case .note:
            EmptyView()
        }
    }

    private var placeholder: some View {
        Image(entry.kind.icon).resizable().frame(width: 44, height: 44).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 240)
            .background(Color.tab)
    }

    /// The photo or video as a print taped onto the page, with the date stamp flickering on.
    private func taped<V: View>(_ content: V) -> some View {
        content
            .overlay(alignment: .bottomTrailing) {
                DateStamp(date: entry.date, size: 22)
                    .padding(.trailing, 12).padding(.bottom, 10)
                    .keyframeAnimator(initialValue: 1.0, trigger: stampFlicker) { stamp, opacity in
                        stamp.opacity(opacity)
                    } keyframes: { _ in
                        LinearKeyframe(0, duration: 0.01)
                        LinearKeyframe(1, duration: 0.07)
                        LinearKeyframe(0.15, duration: 0.06)
                        LinearKeyframe(1, duration: 0.08)
                        LinearKeyframe(0.45, duration: 0.08)
                        LinearKeyframe(1, duration: 0.1)
                    }
                    .onAppear { if !reduceMotion { stampFlicker.toggle() } }
            }
            .padding(EdgeInsets(top: 10, leading: 10, bottom: 30, trailing: 10))
            .background(Color.card)
            .printShadow(14)
            .rotationEffect(.degrees(-1))
            .overlay(alignment: .topLeading) { Tape().rotationEffect(.degrees(-32)).offset(x: -16, y: -2) }
            .overlay(alignment: .topTrailing) { Tape(color: .darkroom).rotationEffect(.degrees(30)).offset(x: 16, y: 0) }
            .padding(.horizontal, 18)
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity)
    }

    private func loadMedia() async {
        guard let id = PhotoService.localID(for: entry) else { return }
        switch entry.kind {
        case .photo:
            image = await PhotoService.image(id, size: CGSize(width: 1600, height: 1600))
        case .video:
            if let item = await PhotoService.playerItem(id) { player = AVPlayer(playerItem: item) }
        default:
            break
        }
    }

    private func delete() {
        ctx.delete(entry)
        try? ctx.save()
        dismiss()
    }
}
