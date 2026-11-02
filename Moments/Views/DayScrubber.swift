import SwiftUI
import SwiftData

/// One day that has entries, with the first entry shown for it.
struct ScrubberDay: Identifiable {
    let date: Date
    let entryID: PersistentIdentifier
    var isMilestone: Bool
    var id: Date { date }
}

/// Right-edge scrubber for jumping to a day. Days are spaced evenly (gaps take no room);
/// years are labelled where they start. Shown while the list scrolls, like Photos.
struct DayScrubber: View {
    let days: [ScrubberDay]
    let isVisible: Bool
    /// Called with true when a drag starts and false when it ends.
    var onScrubbing: (Bool) -> Void
    var onSelect: (ScrubberDay) -> Void

    @State private var index: Int?
    @State private var dragY: CGFloat = 0

    private struct YearMark: Identifiable {
        let year: Int
        let y: CGFloat
        var id: Int { year }
    }

    var body: some View {
        GeometryReader { geo in
            let height = geo.size.height
            Capsule()
                .fill(.track)
                .frame(width: 4)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .padding(.trailing, 8)
                .overlay(alignment: .topTrailing) { milestoneDots(height: height) }
                .overlay(alignment: .topTrailing) { yearLabels(height: height) }
                .overlay(alignment: .topTrailing) { bubble }
                .contentShape(Rectangle())
                .gesture(drag(height: height))
        }
        .frame(width: 44)
        .opacity(isVisible ? 1 : 0)
        .allowsHitTesting(isVisible)
        .animation(.easeInOut(duration: 0.2), value: isVisible)
        .sensoryFeedback(.selection, trigger: index)
    }

    private func yearLabels(height: CGFloat) -> some View {
        ZStack(alignment: .topTrailing) {
            ForEach(yearMarks(height: height)) { m in
                Text(verbatim: "\(m.year)")
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, 4)
                    .background(Color.paper.opacity(0.8), in: Capsule())
                    .offset(x: -18, y: m.y - 7)
            }
        }
        .opacity(index == nil ? 1 : 0)
        .allowsHitTesting(false)
    }

    /// A dot on the track for each day with a milestone.
    private func milestoneDots(height: CGFloat) -> some View {
        ZStack(alignment: .topTrailing) {
            ForEach(Array(days.enumerated()), id: \.element.id) { i, d in
                if d.isMilestone {
                    Circle().fill(.marigold).frame(width: 8, height: 8)
                        .offset(x: -6, y: (CGFloat(i) + 0.5) / CGFloat(days.count) * height - 4)
                }
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder private var bubble: some View {
        if let index {
            HStack(spacing: 6) {
                Text(days[index].date.formatted(date: .abbreviated, time: .omitted))
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.regularMaterial, in: Capsule())
                    .fixedSize()
                Circle().fill(.darkroom).frame(width: 12, height: 12)
            }
            .padding(.trailing, 4)
            .offset(y: dragY - 15)
            .allowsHitTesting(false)
        }
    }

    private func drag(height: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                let y = min(max(v.location.y, 0), height)
                dragY = y
                let i = min(days.count - 1, max(0, Int(y / height * CGFloat(days.count))))
                if index == nil { onScrubbing(true) }
                if i != index {
                    index = i
                    onSelect(days[i])
                }
            }
            .onEnded { _ in
                index = nil
                onScrubbing(false)
            }
    }

    /// The first day of each year, skipping labels that would overlap the previous one.
    private func yearMarks(height: CGFloat) -> [YearMark] {
        var marks: [YearMark] = []
        var lastYear: Int?
        for (i, d) in days.enumerated() {
            let year = Calendar.current.component(.year, from: d.date)
            guard year != lastYear else { continue }
            lastYear = year
            let y = (CGFloat(i) + 0.5) / CGFloat(days.count) * height
            if let prev = marks.last, y - prev.y < 20 { continue }
            marks.append(YearMark(year: year, y: y))
        }
        return marks
    }
}
