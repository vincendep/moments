import SwiftUI
import SwiftData

/// The All tab: every entry, newest first, under month headings, with the day scrubber.
/// A separate list from the milestones, so each keeps its own scroll position.
struct EntriesList: View {
    let timeline: Timeline
    @Environment(\.modelContext) private var ctx

    @State private var scrubberVisible = false
    @State private var scrubbing = false
    @State private var hideScrubber: Task<Void, Never>?

    /// All entries, newest first.
    private var ordered: [Entry] { timeline.sortedEntries }

    private var grouped: [(Date, [Entry])] { timeline.entriesByMonth }
    private var scrubberDays: [ScrubberDay] { timeline.scrubberDays }

    var body: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(grouped, id: \.0) { month, items in
                    Section {
                        // A row rather than a section header: plain lists pin headers on a dark band.
                        MonthHeader(month: month)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 24, leading: 20, bottom: 0, trailing: 20))
                        ForEach(items) { TimelineRow(entry: $0) }
                            .onDelete { idx in
                                idx.forEach { ctx.delete(items[$0]) }
                            }
                    }
                    .listSectionSeparator(.hidden)
                }
            }
            .albumList()
            // iOS 17 has no scroll-offset callback for List; a simultaneous drag doesn't block scrolling.
            .simultaneousGesture(DragGesture(minimumDistance: 10).onChanged { _ in showScrubber() })
            .overlay(alignment: .trailing) {
                if scrubberDays.count >= 2 {
                    DayScrubber(days: scrubberDays, isVisible: scrubberVisible) { active in
                        scrubbing = active
                        showScrubber()
                    } onSelect: { day in
                        proxy.scrollTo(day.entryID, anchor: .top)
                    }
                    .padding(.vertical, 8)
                }
            }
            // A new entry lands at the top, so scroll up to show it; deleting one keeps the place.
            .onChange(of: timeline.entries?.count ?? 0) { old, new in
                guard new > old, let first = ordered.first else { return }
                // Centering the first row clamps to the list's top and keeps its month header visible
                // (a .top anchor would tuck the header under the tabs).
                // Deferred so the list has laid out the new row before scrolling.
                DispatchQueue.main.async { withAnimation { proxy.scrollTo(first.id, anchor: .center) } }
            }
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
}

/// The Milestones tab: only milestones, oldest first, on the marigold thread,
/// with the time between each pair written in the margin.
struct MilestonesList: View {
    let timeline: Timeline
    @Environment(\.modelContext) private var ctx

    var body: some View {
        List {
            if let first = timeline.milestones.first {
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
                        TimelineRow(entry: e, elapsed: e.sinceFirstMilestone(first),
                                    rail: .milestone(isFirst: i == 0, isLast: i == items.count - 1), index: 2 * i)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { ctx.delete(e) } label: {
                                    Label { Text("Delete") } icon: { Image("icon.delete") }
                                }
                            }
                            .milestoneRailRow()
                    }
                }
            }
        }
        .albumList()
    }
}

/// A list row on the album page (no card, separator or chevron), with the leading swipe
/// that marks or unmarks a milestone.
struct TimelineRow: View {
    let entry: Entry
    var elapsed: String? = nil
    var rail: MilestoneRail.Style? = nil
    var index: Int = 0

    var body: some View {
        HStack(spacing: 12) {
            if let rail { MilestoneRail(style: rail, index: index) }
            // Rail rows have no vertical insets (so the line joins up); the padding restores the height.
            ZStack {
                // Hidden link: keeps the row tappable without the disclosure chevron.
                NavigationLink(value: entry) { EmptyView() }.opacity(0)
                EntryRow(entry: entry, elapsed: elapsed)
            }
            .padding(.vertical, rail == nil ? 0 : 10)
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(rail == nil ? EdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20)
                                   : EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
        .sensoryFeedback(.impact(weight: .light), trigger: entry.isMilestone)
        .swipeActions(edge: .leading) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { entry.isMilestone.toggle() }
                entry.modifiedAt = .now
            } label: {
                Label { Text(entry.isMilestone ? "Not a Milestone" : "Milestone") }
                    icon: { Image(entry.isMilestone ? "icon.ribbon" : "icon.ribbon.fill") }
            }
            .tint(.darkroom)
        }
    }
}

private extension View {
    /// The timeline lists' look. Plain: grouped styles clip each section to a rounded card,
    /// cutting off the prints' shadows and tilt.
    func albumList() -> some View {
        listStyle(.plain)
            .foregroundStyle(Color.ink)
            .paperBackground()
    }
}
