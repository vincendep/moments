import SwiftUI
import SwiftData
import PhotosUI
import CoreLocation

struct TimelineView: View {
    let timeline: Timeline
    @Environment(\.modelContext) private var ctx

    @State private var sheet: Sheet?
    /// What the add sheet picked; opened once that sheet has gone.
    @State private var picked: AddMomentSheet.Choice?
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showPicker = false
    /// Several items were picked: asks whether they make one moment or one each.
    @State private var askGrouping = false
    /// Shows only the milestones, each with the time since the first one.
    @State private var milestonesOnly = false
    /// The Milestones list is created on its first visit, so its thread draws in when first seen.
    @State private var milestonesVisited = false

    enum Sheet: Identifiable { case add, camera, note, voice; var id: Self { self } }

    var body: some View {
        // Two lists kept alive side by side, so each tab keeps its own scroll position.
        ZStack {
            EntriesList(timeline: timeline).shown(!milestonesOnly)
            if milestonesOnly || milestonesVisited { MilestonesList(timeline: timeline).shown(milestonesOnly) }
        }
        .safeAreaInset(edge: .top) {
            if !timeline.milestones.isEmpty {
                AlbumTabs(milestonesOnly: $milestonesOnly)
                    .padding(.top, 4)
                    .background(Color.paper)
            }
        }
        .onChange(of: milestonesOnly) { _, on in if on { milestonesVisited = true } }
        // Unmarking the last milestone hides the tabs, so leave the then-empty milestones view.
        .onChange(of: timeline.milestones.isEmpty) { _, none in
            guard none else { return }
            milestonesOnly = false
            milestonesVisited = false
        }
        .overlay {
            if timeline.entries?.isEmpty ?? true {
                ContentUnavailableView {
                    Label { Text("No moments yet") } icon: { Image("icon.timeline") }
                } description: {
                    Text("Tap + to capture the first one.")
                }
            }
        }
        .navigationTitle(timeline.name)
        .navigationDestination(for: Entry.self) { EntryDetailView(entry: $0) }
        .safeAreaInset(edge: .bottom) { shutter }
        .photosPicker(isPresented: $showPicker, selection: $pickerItems,
                      photoLibrary: .shared())
        .onChange(of: pickerItems) { _, items in
            if items.count > 1 { askGrouping = true } else if !items.isEmpty { importItems(items, together: false) }
        }
        .confirmationDialog("Add \(pickerItems.count) photos and videos", isPresented: $askGrouping,
                            titleVisibility: .visible) {
            Button("Add as One Moment") { importItems(pickerItems, together: true) }
            Button("Add as Separate Moments") { importItems(pickerItems, together: false) }
            Button("Cancel", role: .cancel) { pickerItems = [] }
        }
        .sheet(item: $sheet, onDismiss: openPicked) { s in
            switch s {
            case .add:
                AddMomentSheet { choice in
                    picked = choice
                    sheet = nil
                }
            case .camera:
                CameraView(timeline: timeline) { kind, id, location in
                    let entry = Entry(timeline: timeline, media: [MediaItem(kind, assetLocalID: id)])
                    Arrival.mark(entry)
                    ctx.insert(entry)
                    if let location { Task { entry.place = await LocationService.place(for: location) } }
                }
                .ignoresSafeArea()
            case .note: NoteEditorView(timeline: timeline)
            case .voice: VoiceRecorderView(timeline: timeline)
            }
        }
    }

    /// The floating dock, bottom center: a frosted print-white pill with the four kinds of moment
    /// one tap away and the shutter in the middle, which opens the add sheet (with the current place).
    /// Prints scroll and blur behind it; there is no band of paper.
    private var shutter: some View {
        HStack(spacing: 4) {
            dockButton("icon.camera", "Camera") { add(.camera) }
            dockButton("icon.note", "Note") { add(.note) }
            Button { sheet = .add } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.medium))
                    .foregroundStyle(Color.onDarkroom)
                    .frame(width: 60, height: 60)
                    .background(Circle().fill(.darkroomFill))
                    .overlay(Circle().strokeBorder(Color.card, lineWidth: 3).padding(1.5))
            }
            .accessibilityLabel("More ways to add")
            dockButton("icon.voice", "Voice Memo") { add(.voice) }
            dockButton("icon.library", "From Library") { add(.library) }
        }
        .padding(6)
        .background(.ultraThinMaterial, in: Capsule())
        .background(Color.card.opacity(0.55), in: Capsule())
        .overlay(Capsule().strokeBorder(Color.rule))
        .shadow(color: Color.shadow, radius: 14, y: 8)
        .padding(.bottom, 8)
    }

    private func dockButton(_ icon: String, _ label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(icon)
                .resizable()
                .frame(width: 28, height: 28)
                .foregroundStyle(.darkroom)
                .frame(width: 52, height: 52)
                .contentShape(Circle())
        }
        .accessibilityLabel(Text(label))
    }

    /// Opens a capture straight from the dock. Capture sheets ask for location access first
    /// (once); library imports use the photo's own place, so they don't.
    private func add(_ choice: AddMomentSheet.Choice) {
        guard choice != .library else { showPicker = true; return }
        Task {
            await LocationService.requestAccess()
            picked = choice
            openPicked()
        }
    }

    /// Opens what the add sheet picked, once it has gone (a sheet can't open over a dismissing one).
    private func openPicked() {
        guard let choice = picked else { return }
        picked = nil
        switch choice {
        case .camera: sheet = .camera
        case .library: showPicker = true
        case .note: sheet = .note
        case .voice: sheet = .voice
        }
    }

    /// Links existing Photos assets by reference (no copy), optionally adding them to the album: all in one
    /// entry (`together`, dated by the oldest) or one entry each. Entries take the assets' own date and
    /// location, never the current ones.
    private func importItems(_ items: [PhotosPickerItem], together: Bool) {
        let assets = PhotoService.assets(for: items)
        pickerItems = []
        guard !assets.isEmpty else { return }
        var located: [(Entry, CLLocation)] = []
        let groups = together ? [assets] : assets.map { [$0] }
        for group in groups {
            let entry = Entry(timeline: timeline, date: group[0].creationDate ?? .now,
                              media: group.map(PhotoService.item(for:)))
            Arrival.mark(entry)
            ctx.insert(entry)
            if let location = group.lazy.compactMap(\.location).first { located.append((entry, location)) }
        }
        // Named one at a time after inserting, so a large import isn't held up (the geocoder is rate-limited).
        if !located.isEmpty {
            Task {
                for (entry, location) in located { entry.place = await LocationService.place(for: location) }
            }
        }
        PhotoService.addImports(assets, for: timeline)
    }
}

private extension View {
    /// Shows one of the tab lists, or keeps it hidden (and out of reach) without losing its scroll position.
    func shown(_ visible: Bool) -> some View {
        opacity(visible ? 1 : 0)
            .allowsHitTesting(visible)
            .accessibilityHidden(!visible)
    }
}
