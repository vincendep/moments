import SwiftUI
import AVKit
import PhotosUI

/// Shows an entry's media (taped-in prints, one page each, and its voice memos as cassettes), adds more
/// from the camera, the library or the recorder, and edits its title, notes, date and location in place.
struct EntryDetailView: View {
    @Bindable var entry: Entry
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @State private var audio = AudioService()
    /// The memo `audio` is playing (one at a time).
    @State private var playingID: UUID?
    @State private var adding: Adding?
    @State private var showPicker = false
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var memoToRemove: MediaItem?
    @State private var confirmDelete = false
    /// The tallest print seen on the pages, so they fit it without empty bands.
    @State private var pageHeight: CGFloat = 0
    /// The print showing on the pages (nil: the first).
    @State private var page: UUID?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Adding: Identifiable { case camera, voice; var id: Self { self } }

    var body: some View {
        PaperForm {
            if !entry.prints.isEmpty {
                Section { prints }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            if !entry.voiceMemos.isEmpty {
                Section { memos }
                    .listRowInsets(entry.prints.isEmpty && entry.voiceMemos.count == 1
                                   ? EdgeInsets() : EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            Section { addMenu }
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
                        switch entry.prints.count {
                        case 0: Text("This can't be undone.")
                        case 1: Text("The photo or video stays in your Photos library.")
                        default: Text("The photos and videos stay in your Photos library.")
                        }
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
        .confirmationDialog("Remove this voice memo?", isPresented: Binding(get: { memoToRemove != nil },
                                                                           set: { if !$0 { memoToRemove = nil } }),
                            titleVisibility: .visible, presenting: memoToRemove) { memo in
            Button("Remove", role: .destructive) { remove(memo) }
        } message: { _ in
            Text("This can't be undone.")
        }
        .sheet(item: $adding) { kind in
            switch kind {
            case .camera:
                if let timeline = entry.timeline {
                    CameraView(timeline: timeline) { kind, id, _ in
                        entry.add(MediaItem(kind, assetLocalID: id))
                    }
                    .ignoresSafeArea()
                }
            case .voice:
                if let timeline = entry.timeline { VoiceRecorderView(timeline: timeline, adding: entry) }
            }
        }
        .photosPicker(isPresented: $showPicker, selection: $pickerItems, photoLibrary: .shared())
        .onChange(of: pickerItems) { _, items in addFromLibrary(items) }
        .onDisappear {
            audio.stopPlaying()
            if !entry.isDeleted {
                if entry.hasChanges { entry.modifiedAt = .now }
                try? ctx.save()
            }
        }
    }

    /// How far the ribbon drops in from when marking a milestone (none when unmarking or with Reduce Motion).
    private var ribbonDrop: CGFloat { entry.isMilestone && !reduceMotion ? -14 : 0 }

    /// One print taped in, or several on pages to swipe through.
    @ViewBuilder private var prints: some View {
        let items = entry.prints
        if items.count == 1, let item = items.first {
            PrintPage(item: item, date: entry.date).contextMenu { printMenu(item) }
        } else {
            TabView(selection: $page) {
                ForEach(items) { item in
                    // Sized to the photo, as a single print is in the form; the pages take the tallest one's height.
                    PrintPage(item: item, date: entry.date)
                        .fixedSize(horizontal: false, vertical: true)
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: {
                            pageHeight = max(pageHeight, $0)
                        }
                        .tag(Optional(item.uuid))
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            // Room below the prints for the page dots.
            .frame(height: max(pageHeight, 300) + 36)
            // On the pager, for the page showing: the pages' own scroller swallows a long press on them.
            .contextMenu {
                if let item = items.first(where: { $0.uuid == page }) ?? items.first { printMenu(item) }
            }
        }
    }

    @ViewBuilder private func printMenu(_ item: MediaItem) -> some View {
        if item != entry.cover {
            Button { withAnimation { entry.makeCover(item) } } label: { Label("Make Cover", systemImage: "star") }
        }
        Button(role: .destructive) { remove(item) } label: {
            Label { Text("Remove") } icon: { Image("icon.delete") }
        }
    }

    /// A single voice memo (and nothing else) keeps the big cassette; otherwise each memo is a cassette card.
    @ViewBuilder private var memos: some View {
        let items = entry.voiceMemos
        if entry.prints.isEmpty, items.count == 1, let memo = items.first {
            VStack(spacing: 16) {
                CassetteView(title: entry.displayTitle, spinning: isPlaying(memo))
                Button { toggle(memo) } label: {
                    Label {
                        Text(isPlaying(memo) ? "Stop" : "Play Voice Memo")
                    } icon: {
                        if isPlaying(memo) { Image(systemName: "stop.fill") } else { Image("icon.play") }
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
            .contentShape(Rectangle())
            .contextMenu { removeMemoButton(memo) }
        } else {
            ForEach(items) { memo in
                CassetteCard(isPlaying: isPlaying(memo)) { toggle(memo) } label: { MemoLabel(memo: memo) }
                    .padding(.horizontal, 18)
                    .contextMenu { removeMemoButton(memo) }
            }
        }
    }

    private func removeMemoButton(_ memo: MediaItem) -> some View {
        Button(role: .destructive) { memoToRemove = memo } label: {
            Label { Text("Remove") } icon: { Image("icon.delete") }
        }
    }

    /// Adds a photo, video or voice memo to this entry; its date and place stay as they are.
    private var addMenu: some View {
        Menu {
            Button { adding = .camera } label: { Label { Text("Camera") } icon: { Image("icon.camera") } }
            Button { showPicker = true } label: { Label { Text("From Library") } icon: { Image("icon.library") } }
            Button { adding = .voice } label: { Label { Text("Voice Memo") } icon: { Image("icon.voice") } }
        } label: {
            Label("Add to This Moment", systemImage: "plus")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func isPlaying(_ memo: MediaItem) -> Bool { audio.isPlaying && playingID == memo.uuid }

    private func toggle(_ memo: MediaItem) {
        if isPlaying(memo) {
            audio.stopPlaying()
        } else if let data = memo.audioData {
            audio.play(data)
            playingID = memo.uuid
        }
    }

    /// Links the picked assets (oldest first), also adding them to the album when the timeline's settings ask.
    private func addFromLibrary(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        let assets = PhotoService.assets(for: items)
        pickerItems = []
        for asset in assets { entry.add(PhotoService.item(for: asset)) }
        if let timeline = entry.timeline { PhotoService.addImports(assets, for: timeline) }
    }

    private func remove(_ item: MediaItem) {
        if isPlaying(item) { audio.stopPlaying() }
        withAnimation { entry.remove(item) }
    }

    private func delete() {
        ctx.delete(entry)
        try? ctx.save()
        dismiss()
    }
}

/// A photo or video as a print taped onto the page, with the date stamp flickering on.
/// Loads its own image or player, and pauses the video once swiped away.
private struct PrintPage: View {
    let item: MediaItem
    let date: Date
    @State private var image: UIImage?
    @State private var player: AVPlayer?
    /// Flipped on appear to flicker the date stamp on, like an old LCD.
    @State private var stampFlicker = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            switch item.kind {
            case .video:
                if let player {
                    taped(VideoPlayer(player: player).frame(height: 300))
                } else {
                    taped(placeholder)
                }
            default:
                if let image {
                    taped(Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 440))
                } else {
                    taped(placeholder)
                }
            }
        }
        .task(id: item.uuid) { await load() }
        .onDisappear { player?.pause() }
    }

    private var placeholder: some View {
        Image(item.kind == .video ? "icon.camera" : "icon.library")
            .resizable().frame(width: 44, height: 44).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 240)
            .background(Color.tab)
    }

    private func taped<V: View>(_ content: V) -> some View {
        content
            .overlay(alignment: .bottomTrailing) {
                DateStamp(date: date, size: 22)
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

    private func load() async {
        guard let id = PhotoService.localID(for: item) else { return }
        switch item.kind {
        case .video:
            if let playerItem = await PhotoService.playerItem(id) { player = AVPlayer(playerItem: playerItem) }
        default:
            image = await PhotoService.image(id, size: CGSize(width: 1600, height: 1600))
        }
    }
}

/// "Voice Memo" and its length, beside a memo's cassette card.
private struct MemoLabel: View {
    let memo: MediaItem
    @State private var length: TimeInterval?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Voice Memo").font(.headline)
            if let length {
                Text(Duration.seconds(length), format: .time(pattern: .minuteSecond))
                    .font(.meta).foregroundStyle(.secondary)
            }
        }
        .task(id: memo.uuid) {
            length = memo.audioData.flatMap { try? AVAudioPlayer(data: $0) }?.duration
        }
    }
}
