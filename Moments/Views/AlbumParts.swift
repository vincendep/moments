import SwiftUI
import UIKit

/// The milestone ribbon: a bookmark hanging over the top edge of a print or card.
struct RibbonShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.midX, y: r.maxY - r.height * 0.22))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

struct Ribbon: View {
    var width: CGFloat = 24

    var body: some View {
        RibbonShape()
            .fill(.marigold)
            .overlay(alignment: .top) { Rectangle().fill(.black.opacity(0.12)).frame(height: width * 0.16) }
            .frame(width: width, height: width * 1.42)
            .shadow(color: Color.shadow, radius: 2, y: 2)
            .accessibilityLabel("Milestone")
    }
}

/// "All | Milestones" as album divider tabs: the selected one is a print-white folder tab.
struct AlbumTabs: View {
    @Binding var milestonesOnly: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            tab(selected: !milestonesOnly) { milestonesOnly = false } label: { Text("All") }
            tab(selected: milestonesOnly) { milestonesOnly = true } label: {
                HStack(spacing: 6) {
                    RibbonShape().fill(.marigold).frame(width: 10, height: 14).accessibilityHidden(true)
                    Text("Milestones")
                }
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .background(alignment: .bottom) { Rectangle().fill(Color.rule).frame(height: 1) }
    }

    private func tab<L: View>(selected: Bool, action: @escaping () -> Void, @ViewBuilder label: () -> L) -> some View {
        let shape = UnevenRoundedRectangle(topLeadingRadius: 8, topTrailingRadius: 8)
        return Button(action: action) {
            label()
                .font(.subheadline.weight(selected ? .semibold : .medium))
                .foregroundStyle(selected ? Color.ink : Color.secondary)
                .padding(.horizontal, 18)
                .frame(minHeight: 44)
                .background(selected ? Color.card : Color.tab, in: shape)
                .overlay { if selected { shape.stroke(Color.rule, lineWidth: 1).padding(.bottom, -1) } }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// A cassette whose reels turn while `spinning` (a voice memo playing or recording).
struct CassetteView: View {
    let title: String
    var spinning: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // The app's own TimelineView shadows SwiftUI's.
        SwiftUI.TimelineView(.animation(paused: !spinning || reduceMotion)) { context in
            let angle = Angle.degrees(context.date.timeIntervalSinceReferenceDate * 150)
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 10).fill(Color.card)
                RoundedRectangle(cornerRadius: 10).strokeBorder(Color.darkroom, lineWidth: 2.5)
                VStack(spacing: 12) {
                    Text(title)
                        .font(AlbumFont.hand(20))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(.horizontal, 8)
                        .frame(maxWidth: .infinity, minHeight: 30)
                        .background(Color.tab, in: RoundedRectangle(cornerRadius: 3))
                    Capsule().fill(Color.ink)
                        .frame(width: 136, height: 46)
                        .overlay {
                            HStack(spacing: 50) { reel(angle); reel(angle) }
                        }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                TrapezoidShape()
                    .stroke(Color.darkroom, style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
                    .frame(width: 120, height: 18)
            }
            .frame(width: 230, height: 150)
        }
        .accessibilityHidden(true)
    }

    private func reel(_ angle: Angle) -> some View {
        ZStack {
            Circle().fill(Color.paper)
            ForEach(0..<3) { i in
                Capsule().fill(Color.ink).frame(width: 3, height: 8).offset(y: -7)
                    .rotationEffect(.degrees(Double(i) * 120))
            }
        }
        .frame(width: 28, height: 28)
        .rotationEffect(angle)
    }
}

private struct TrapezoidShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + 12, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - 12, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        return p
    }
}

/// A postmark stamped over a place: two rings, the town and the date, and cancellation waves.
struct Postmark: View {
    let place: String
    let date: Date

    /// The town: the part after the last comma ("Golden Gate Park, San Francisco" → "SAN FRANCISCO").
    private var town: String {
        (place.split(separator: ",").last.map(String.init) ?? place).trimmingCharacters(in: .whitespaces).uppercased()
    }

    var body: some View {
        HStack(spacing: 2) {
            ZStack {
                Circle().strokeBorder(lineWidth: 2.5)
                Circle().strokeBorder(lineWidth: 1).padding(8)
                VStack(spacing: 2) {
                    Text(town).font(.postmarkTitle).tracking(0.5)
                        .lineLimit(2).multilineTextAlignment(.center).minimumScaleFactor(0.7)
                    Text(date.formatted(.dateTime.day().month(.abbreviated).year(.twoDigits)).uppercased())
                        .font(.postmarkDate).tracking(0.5)
                }
                .frame(width: 50)
            }
            .frame(width: 74, height: 74)
            Waves().stroke(style: StrokeStyle(lineWidth: 2.5, lineCap: .round)).frame(width: 24, height: 34)
        }
        .foregroundStyle(.postmark)
        .rotationEffect(.degrees(-12))
        .accessibilityHidden(true)
    }

    private struct Waves: Shape {
        func path(in r: CGRect) -> Path {
            var p = Path()
            for row in 0..<3 {
                let y = r.minY + CGFloat(row) * r.height / 2
                p.move(to: CGPoint(x: r.minX, y: y))
                p.addCurve(to: CGPoint(x: r.maxX, y: y),
                           control1: CGPoint(x: r.minX + r.width / 3, y: y - 5),
                           control2: CGPoint(x: r.minX + 2 * r.width / 3, y: y + 5))
            }
            return p
        }
    }
}

extension Font {
    static let postmarkTitle = Font.system(size: 9, weight: .bold)
    static let postmarkDate = Font.system(size: 8, weight: .medium)
}

/// Notes on lined letter paper, the lines matching the text's line height (also with Dynamic Type).
/// Shared by an entry's details and the note editor.
struct NotesSection: View {
    @Binding var text: String
    var minHeight: CGFloat = 140
    @ScaledMetric(relativeTo: .body) private var lineHeight: CGFloat = 28

    var body: some View {
        Section("Notes") {
            TextEditor(text: $text)
                .lineSpacing(max(0, lineHeight - UIFont.preferredFont(forTextStyle: .body).lineHeight))
                .scrollContentBackground(.hidden)
                .frame(minHeight: minHeight)
                .padding(.leading, 8)
                // UITextView's default top inset is 8 points.
                .background(LetterPaper(lineHeight: lineHeight, topInset: 8))
                .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))
        }
    }
}

/// Entries just added on this device, so each develops into the timeline once.
@MainActor
enum Arrival {
    private static var pending: Set<UUID> = []

    static func mark(_ entry: Entry) { pending.insert(entry.uuid) }

    /// True the first time a just-added entry appears.
    static func take(_ entry: Entry) -> Bool { pending.remove(entry.uuid) != nil }
}
