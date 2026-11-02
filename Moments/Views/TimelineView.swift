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
    @State private var scrubberVisible = false
    @State private var scrubbing = false
    @State private var hideScrubber: Task<Void, Never>?
    /// Shows only the milestones, each with the time since the first one.
    @State private var milestonesOnly = false

    enum Sheet: Identifiable { case add, camera, note, voice; var id: Self { self } }

    /// All entries, newest first. (The milestones view is oldest first: `timeline.milestones`.)
    private var ordered: [Entry] { timeline.sortedEntries }

    /// Consecutive entries grouped by the start of their month, keeping `ordered`'s order.
    private var grouped: [(Date, [Entry])] {
        var groups: [(Date, [Entry])] = []
        for e in ordered {
            let month = Calendar.current.dateInterval(of: .month, for: e.date)?.start ?? e.date
            if groups.last?.0 == month { groups[groups.count - 1].1.append(e) } else { groups.append((month, [e])) }
        }
        return groups
    }

    /// One item per day with entries, in display order, pointing at that day's first row.
    private var scrubberDays: [ScrubberDay] {
        var days: [ScrubberDay] = []
        for e in ordered {
            let day = Calendar.current.startOfDay(for: e.date)
            if days.last?.date != day {
                days.append(ScrubberDay(date: day, entryID: e.id, isMilestone: e.isMilestone))
            } else if e.isMilestone {
                days[days.count - 1].isMilestone = true
            }
        }
        return days
    }

    var body: some View {
        ScrollViewReader { proxy in
        List {
            if milestonesOnly, let first = timeline.milestones.first {
                let items = timeline.milestones
                Section {
                    // Each milestone after the first is preceded by a row with the time since the previous one,
                    // written in the margin beside the thread.
                    ForEach(Array(items.enumerated()), id: \.element.id) { i, e in
                        if i > 0 {
                            HStack(spacing: 12) {
                                MilestoneRail(style: .interval, index: 2 * i - 1)
                                Image("icon.hourglass").foregroundStyle(.pencil).accessibilityHidden(true)
                                Text(e.interval(since: items[i - 1]))
                                    .font(.margin).foregroundStyle(.pencil)
                                    .padding(.vertical, 8)
                                Spacer()
                            }
                            .milestoneRailRow()
                        }
                        row(e, elapsed: e.sinceFirstMilestone(first),
                            rail: .milestone(isFirst: i == 0, isLast: i == items.count - 1), index: 2 * i)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { ctx.delete(e) } label: {
                                    Label { Text("Delete") } icon: { Image("icon.delete") }
                                }
                            }
                            .milestoneRailRow()
                    }
                }
            } else {
                ForEach(grouped, id: \.0) { month, items in
                    Section {
                        // A row rather than a section header: plain lists pin headers on a dark band.
                        MonthHeader(month: month)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 24, leading: 20, bottom: 0, trailing: 20))
                        ForEach(items) { row($0) }
                            .onDelete { idx in
                                idx.forEach { ctx.delete(items[$0]) }
                            }
                    }
                    .listSectionSeparator(.hidden)
                }
            }
        }
        // Plain: grouped styles clip each section to a rounded card, cutting off the prints' shadows and tilt.
        .listStyle(.plain)
        .foregroundStyle(Color.ink)
        .paperBackground()
        .safeAreaInset(edge: .top) {
            if !timeline.milestones.isEmpty {
                AlbumTabs(milestonesOnly: $milestonesOnly)
                    .padding(.top, 4)
                    .background(Color.paper)
            }
        }
        // iOS 17 has no scroll-offset callback for List; a simultaneous drag doesn't block scrolling.
        .simultaneousGesture(DragGesture(minimumDistance: 10).onChanged { _ in showScrubber() })
        .overlay(alignment: .trailing) {
            if !milestonesOnly, scrubberDays.count >= 2 {
                DayScrubber(days: scrubberDays, isVisible: scrubberVisible) { active in
                    scrubbing = active
                    showScrubber()
                } onSelect: { day in
                    proxy.scrollTo(day.entryID, anchor: .top)
                }
                .padding(.vertical, 8)
            }
        }
        .onAppear { scrollToTop(proxy, animated: false) }
        .onChange(of: timeline.entries?.count) { scrollToTop(proxy, animated: true) }
        .onChange(of: milestonesOnly) { scrollToTop(proxy, animated: false) }
        // Unmarking the last milestone hides the tabs, so leave the then-empty milestones view.
        .onChange(of: timeline.milestones.isEmpty) { _, none in if none { milestonesOnly = false } }
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
        .onChange(of: pickerItems) { _, items in importItems(items) }
        .sheet(item: $sheet, onDismiss: openPicked) { s in
            switch s {
            case .add:
                AddMomentSheet { choice in
                    picked = choice
                    sheet = nil
                }
            case .camera:
                CameraView(timeline: timeline) { kind, id, location in
                    let entry = Entry(kind: kind, timeline: timeline, assetLocalID: id,
                                      assetCloudID: PhotoService.cloudID(forLocalID: id))
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

    /// A list row on the album page (no card, separator or chevron), with the leading swipe
    /// that marks or unmarks a milestone.
    private func row(_ e: Entry, elapsed: String? = nil, rail: MilestoneRail.Style? = nil, index: Int = 0) -> some View {
        HStack(spacing: 12) {
            if let rail { MilestoneRail(style: rail, index: index) }
            // Rail rows have no vertical insets (so the line joins up); the padding restores the height.
            ZStack {
                // Hidden link: keeps the row tappable without the disclosure chevron.
                NavigationLink(value: e) { EmptyView() }.opacity(0)
                EntryRow(entry: e, elapsed: elapsed)
            }
            .padding(.vertical, rail == nil ? 0 : 10)
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(rail == nil ? EdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20)
                                   : EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
        .sensoryFeedback(.impact(weight: .light), trigger: e.isMilestone)
        .swipeActions(edge: .leading) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { e.isMilestone.toggle() }
                e.modifiedAt = .now
            } label: {
                Label { Text(e.isMilestone ? "Not a Milestone" : "Milestone") }
                    icon: { Image(e.isMilestone ? "icon.ribbon" : "icon.ribbon.fill") }
            }
            .tint(.darkroom)
        }
    }

    /// Shows the day scrubber and hides it again 1.5 s after the last scroll or drag.
    private func showScrubber() {
        scrubberVisible = true
        hideScrubber?.cancel()
        hideScrubber = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled, !scrubbing else { return }
            scrubberVisible = false
        }
    }

    /// Scrolls to the first row: the newest entry, or in the milestones view the first milestone.
    private func scrollToTop(_ proxy: ScrollViewProxy, animated: Bool) {
        guard let first = milestonesOnly ? timeline.milestones.first : timeline.sortedEntries.first else { return }
        // Centering the first row clamps to the list's top and keeps its month header visible
        // (a .top anchor would tuck the header under the bar).
        // Deferred so the list has laid out its rows before scrolling.
        DispatchQueue.main.async {
            if animated {
                withAnimation { proxy.scrollTo(first.id, anchor: .center) }
            } else {
                proxy.scrollTo(first.id, anchor: .center)
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

    /// Links existing Photos assets by reference (no copy), optionally adding them to the album.
    /// Entries take the asset's own date and location, never the current ones.
    private func importItems(_ items: [PhotosPickerItem]) {
        var ids: [String] = []
        var located: [(Entry, CLLocation)] = []
        for item in items {
            guard let id = item.itemIdentifier, let asset = PhotoService.asset(id) else { continue }
            let kind: EntryKind = asset.mediaType == .video ? .video : .photo
            let entry = Entry(kind: kind, timeline: timeline, date: asset.creationDate ?? .now, assetLocalID: id,
                              assetCloudID: PhotoService.cloudID(forLocalID: id))
            Arrival.mark(entry)
            ctx.insert(entry)
            ids.append(id)
            if let location = asset.location { located.append((entry, location)) }
        }
        pickerItems = []
        // Named one at a time after inserting, so a large import isn't held up (the geocoder is rate-limited).
        if !located.isEmpty {
            Task {
                for (entry, location) in located { entry.place = await LocationService.place(for: location) }
            }
        }
        guard timeline.addImportsToAlbum, !ids.isEmpty else { return }
        Task {
            if let album = try? await PhotoService.album(for: timeline) {
                try? await PhotoService.add(assetIDs: ids, to: album)
            }
        }
    }
}
