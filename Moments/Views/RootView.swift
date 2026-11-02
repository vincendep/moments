import SwiftUI
import SwiftData

/// Shows the current timeline full screen; the title menu switches between timelines.
struct RootView: View {
    /// The app's website, where people can leave a tip; the title menu links to it once set.
    /// Keep the in-app label neutral: outside the US, the App Store forbids pointing to payments outside in-app purchase.
    static let website: URL? = nil
    /// The first-launch timeline's name, in the user's language; an untouched one is recognised by it.
    private static let defaultTimelineName = String(localized: "My Timeline")

    @Environment(\.modelContext) private var ctx
    @Query(sort: \Timeline.createdAt) private var timelines: [Timeline]
    /// Set once the first-launch default timeline has been created, so deleting it later doesn't bring it back.
    @AppStorage("seededDefaultTimeline") private var seeded = false
    /// `Timeline.uuid` of that default timeline, until it is removed or used.
    @AppStorage("seededTimelineID") private var seededTimelineID = ""
    /// `Timeline.uuid` of the current timeline; the app reopens it on launch.
    @AppStorage("lastTimelineID") private var lastTimelineID = ""

    @State private var creating = false
    /// The timeline whose settings sheet is open (held so deleting it doesn't swap the sheet's content).
    @State private var editing: Timeline?

    /// The last used timeline, falling back to the first one (e.g. after it was deleted).
    private var current: Timeline? {
        timelines.first { $0.uuid.uuidString == lastTimelineID } ?? timelines.first
    }

    var body: some View {
        NavigationStack {
            Group {
                if let current {
                    TimelineView(timeline: current)
                        .id(current.uuid)
                        .toolbarTitleMenu { titleMenu(current) }
                        // The title menu only appears with an inline title.
                        .navigationBarTitleDisplayMode(.inline)
                } else {
                    ContentUnavailableView {
                        Label { Text("No timelines yet") } icon: { Image("icon.timeline") }
                    } description: {
                        Text("Create a timeline to start collecting moments.")
                    } actions: {
                        Button("New Timeline…") { creating = true }
                            .buttonStyle(.borderedProminent)
                            .tint(.darkroomFill)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.paper)
                    .navigationTitle("Moments")
                }
            }
            .toolbar {
                if let current {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { editing = current } label: { Image("icon.dial").foregroundStyle(.darkroom) }
                            .accessibilityLabel("Timeline Settings")
                    }
                }
            }
        }
        .sheet(isPresented: $creating) {
            TimelineEditorView(timeline: nil) { lastTimelineID = $0.uuid.uuidString }
        }
        .sheet(item: $editing) { TimelineEditorView(timeline: $0) }
        .onAppear {
            // Menus and other UIKit-presented UI take the window's tint, which SwiftUI's doesn't set.
            for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
                scene.windows.forEach { $0.tintColor = UIColor(named: "AccentColor") }
            }
            guard !seeded else { return }
            if timelines.isEmpty {
                let t = Timeline(name: Self.defaultTimelineName)
                ctx.insert(t)
                seededTimelineID = t.uuid.uuidString
            }
            seeded = true
        }
        .onChange(of: timelines.count) { removeRedundantDefaultTimeline() }
        .task {
            if await PhotoService.requestAccess() { PhotoService.backfillCloudIDs(in: ctx) }
        }
    }

    /// On a new device the default timeline is created before iCloud delivers the user's data.
    /// Timelines older than it can only have come from iCloud, so an untouched default is dropped.
    private func removeRedundantDefaultTimeline() {
        guard !seededTimelineID.isEmpty,
              let seed = timelines.first(where: { $0.uuid.uuidString == seededTimelineID }) else { return }
        guard seed.entries?.isEmpty ?? true, seed.name == Self.defaultTimelineName else {
            seededTimelineID = ""   // the user started using it: keep it for good
            return
        }
        guard timelines.contains(where: { $0.createdAt < seed.createdAt }) else { return }
        ctx.delete(seed)
        try? ctx.save()
        seededTimelineID = ""
    }

    @ViewBuilder private func titleMenu(_ current: Timeline) -> some View {
        Picker("Timeline", selection: Binding(get: { current.uuid.uuidString },
                                              set: { lastTimelineID = $0 })) {
            ForEach(timelines) { Text($0.name).tag($0.uuid.uuidString) }
        }
        Divider()
        Button("New Timeline…", systemImage: "plus") { creating = true }
        if let website = Self.website {
            Link(destination: website) { Label("Moments Website", systemImage: "safari") }
        }
    }
}
