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
    /// Access that's off, explained with a way to Settings.
    @State private var missing: Access?
    /// The camera couldn't save its capture: explained once its sheet has gone.
    @State private var captureFailed = false
    /// The tallest print seen on the pages, so they fit it without empty bands.
    @State private var pageHeight: CGFloat = 0
    /// The title field is out of sight, so the bar shows the title instead.
    @State private var titleScrolledAway = false
    /// The print showing on the pages (nil: the first).
    @State private var page: UUID?
    /// The screen's width and the media's, so the pager can run to the screen edges (see `bleed`).
    @State private var formWidth: CGFloat = 0
    @State private var mediaWidth: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Adding: Identifiable { case camera, voice; var id: Self { self } }

    var body: some View {
        PaperForm {
            // The title heads the page; the bar shows it only once it has scrolled away.
            TitleSection(title: $entry.title, placeholder: entry.dateLabel, scrolledAway: $titleScrolledAway)
            // The media is a section header without rows: a form clips its rows to their rounded cards, which
            // would cut the tape and the prints sliding past the margin; a header isn't clipped.
            if !entry.sortedMedia.isEmpty {
                Section {} header: {
                    VStack(spacing: 12) {
                        if !entry.prints.isEmpty { prints }
                        memos
                    }
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { mediaWidth = $0 }
                    .textCase(nil)
                    .foregroundStyle(Color.ink)
                    .listRowInsets(EdgeInsets())
                }
            }
            NotesSection(text: $entry.text, minHeight: 120)
            WhenWhereSection(date: $entry.date, hasTime: $entry.hasTime, place: $entry.place, postmarkDate: entry.date)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { formWidth = $0 }
        .navigationTitle(titleScrolledAway ? entry.displayTitle : "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                milestoneButton
                actionsMenu
            }
        }
        .confirmationDialog("Delete this entry?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete Entry", role: .destructive, action: delete)
        } message: {
            switch entry.prints.count {
            case 0: Text("This can't be undone.")
            case 1: Text("The photo or video stays in your Photos library.")
            default: Text("The photos and videos stay in your Photos library.")
            }
        }
        .confirmationDialog("Remove this voice memo?", isPresented: Binding(get: { memoToRemove != nil },
                                                                           set: { if !$0 { memoToRemove = nil } }),
                            titleVisibility: .visible, presenting: memoToRemove) { memo in
            Button("Remove", role: .destructive) { remove(memo) }
        } message: { _ in
            Text("This can't be undone.")
        }
        .accessAlert($missing)
        .sheet(item: $adding, onDismiss: {
            if captureFailed { captureFailed = false; missing = .photos }
        }) { kind in
            switch kind {
            case .camera:
                if let timeline = entry.timeline {
                    CameraView(timeline: timeline, onFailed: { captureFailed = true }) { kind, id, _ in
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

    /// The form's margin on each side of the media: the pager reaches past it to the screen edges.
    private var bleed: CGFloat { max(0, (formWidth - mediaWidth) / 2) }

    /// How far the ribbon drops in from when marking a milestone (none when unmarking or with Reduce Motion).
    private var ribbonDrop: CGFloat { entry.isMilestone && !reduceMotion ? -14 : 0 }

    /// One print taped in, or several on pages to swipe through.
    @ViewBuilder private var prints: some View {
        let items = entry.prints
        if items.count == 1, let item = items.first {
            PrintPage(item: item, date: entry.date) { ItemActions { printMenu(item) } }
        } else {
            TabView(selection: $page) {
                ForEach(items) { item in
                    // Sized to the photo, as a single print is in the form; the pages take the tallest one's height.
                    PrintPage(item: item, date: entry.date) { ItemActions { printMenu(item) } }
                        .fixedSize(horizontal: false, vertical: true)
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: {
                            pageHeight = max(pageHeight, $0)
                        }
                        .padding(.horizontal, bleed)
                        .tag(Optional(item.uuid))
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            // Room below the prints for the page dots.
            .frame(height: max(pageHeight, 300) + 36)
            // Edge to edge, so a print slides off the screen rather than being cut at the form's margin.
            .padding(.horizontal, -bleed)
            // Opens on the first print, also when the pager widens once the widths are known.
            .onAppear { if page == nil { page = items.first?.uuid } }
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
                HStack {
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
                    ItemActions { removeMemoButton(memo) }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        } else {
            ForEach(items) { memo in
                CassetteCard(isPlaying: isPlaying(memo)) { toggle(memo) } label: {
                    MemoLabel(memo: memo)
                } actions: {
                    ItemActions { removeMemoButton(memo) }
                }
            }
        }
    }

    private func removeMemoButton(_ memo: MediaItem) -> some View {
        Button(role: .destructive) { memoToRemove = memo } label: {
            Label { Text("Remove") } icon: { Image("icon.delete") }
        }
    }

    /// The entry's actions, top right: adding a photo, video or voice memo (the entry's date and place stay
    /// as they are) and deleting it.
    private var actionsMenu: some View {
        Menu {
            Section("Add to This Moment") {
                Button { open(.camera) } label: { Label { Text("Camera") } icon: { Image("icon.camera") } }
                Button { open(nil) } label: { Label { Text("From Library") } icon: { Image("icon.library") } }
                Button { open(.voice) } label: { Label { Text("Voice Memo") } icon: { Image("icon.voice") } }
            }
            Button(role: .destructive) { confirmDelete = true } label: {
                Label { Text("Delete Entry") } icon: { Image("icon.delete") }
            }
        } label: {
            Label("Options", systemImage: "ellipsis.circle")
        }
    }

    /// The ribbon, beside the menu: outlined in red, filled in marigold (the milestone mark) when it is one.
    /// Marking drops it in from above.
    private var milestoneButton: some View {
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

    private func isPlaying(_ memo: MediaItem) -> Bool { audio.isPlaying && playingID == memo.uuid }

    private func toggle(_ memo: MediaItem) {
        if isPlaying(memo) {
            audio.stopPlaying()
        } else if let data = memo.audioData {
            audio.play(data)
            playingID = memo.uuid
        }
    }

    /// Opens a capture sheet, or the library picker for nil, once the access it needs is given.
    private func open(_ kind: Adding?) {
        let needed: [Access] = switch kind {
        case .camera: [.camera, .photos]
        case .voice: [.microphone]
        case nil: [.photos]
        }
        Task {
            if let off = await Access.request(needed) { missing = off; return }
            if let kind { adding = kind } else { showPicker = true }
        }
    }

    /// Links the picked assets (oldest first), also adding them to the album when the timeline's settings ask.
    private func addFromLibrary(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        let assets = PhotoService.assets(for: items)
        pickerItems = []
        // With limited access, items that weren't shared with the app can't be found.
        if assets.count < items.count { missing = .unsharedPhotos }
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

/// A photo or video as a print taped onto the page, with the date stamp flickering on and its actions
/// in the bottom border. Loads its own image or player, and pauses the video once swiped away.
private struct PrintPage<Actions: View>: View {
    let item: MediaItem
    let date: Date
    @ViewBuilder var actions: Actions
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
            .overlay(alignment: .bottomLeading) { actions.padding(.leading, 2) }
            .printShadow(14)
            .rotationEffect(.degrees(-1))
            .overlay(alignment: .topLeading) { Tape().rotationEffect(.degrees(-32)).offset(x: -16, y: -2) }
            .overlay(alignment: .topTrailing) { Tape(color: .darkroom).rotationEffect(.degrees(30)).offset(x: 16, y: 0) }
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

/// "⋯", opening a print's or memo's actions. A button rather than a long press, which doesn't reach
/// views in the form's header, where the media is.
private struct ItemActions<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        Menu { content } label: {
            Image(systemName: "ellipsis")
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 30)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Options")
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
