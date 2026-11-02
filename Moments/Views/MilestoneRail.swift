import SwiftUI

/// The milestones view's leading column: a marigold thread through every row, pinned at each milestone.
/// Rows have no vertical insets or separators, so the segments join into a single thread. On appear the
/// thread draws itself top to bottom, segment by segment (`index` is the row's position).
struct MilestoneRail: View {
    enum Style: Equatable {
        case milestone(isFirst: Bool, isLast: Bool)
        /// The stretch between two milestones, beside the time between them.
        case interval
    }

    let style: Style
    var index = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drawn = false

    var body: some View {
        VStack(spacing: 0) {
            switch style {
            case .interval:
                line
            case .milestone(let isFirst, let isLast):
                line.opacity(isFirst ? 0 : 1)
                line.opacity(isLast ? 0 : 1)
            }
        }
        .frame(width: 20)
        .frame(maxHeight: .infinity)
        .overlay {
            if case .milestone = style {
                Circle().fill(.marigold)
                    .frame(width: 14, height: 14)
                    .overlay(Circle().strokeBorder(Color.paper, lineWidth: 3).padding(-3))
                    .shadow(color: Color.shadow, radius: 2, y: 1)
                    .scaleEffect(drawn ? 1 : 0)
            }
        }
        .accessibilityHidden(true)
        .onAppear {
            guard !drawn else { return }
            if reduceMotion {
                drawn = true
            } else {
                withAnimation(.easeInOut(duration: 0.25).delay(Double(index) * 0.1)) { drawn = true }
            }
        }
    }

    private var line: some View {
        Rectangle().fill(.marigold).frame(width: 2).frame(maxHeight: .infinity)
            .scaleEffect(x: 1, y: drawn ? 1 : 0, anchor: .top)
    }
}

extension View {
    /// List-row settings for the milestones view: no vertical insets or separators, so the thread is unbroken.
    func milestoneRailRow() -> some View {
        listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}
