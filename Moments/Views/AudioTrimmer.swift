import SwiftUI

/// Picks the part of a fresh voice memo to keep: its waveform with a handle at each end.
/// The cut is made on save (`AudioService.trim`).
struct AudioTrimmer: View {
    let data: Data
    let duration: TimeInterval
    @Binding var range: ClosedRange<TimeInterval>
    /// Where playback is, while playing.
    var playhead: TimeInterval?
    @State private var levels: [Float] = []
    @ScaledMetric private var height: CGFloat = 56

    /// The shortest part that can be kept, and how far a VoiceOver adjustment moves a handle.
    static let minimum: TimeInterval = 0.5
    private static let bars = 60

    private enum Edge { case start, end }

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let width = geo.size.width
                ZStack(alignment: .leading) {
                    waveform
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.darkroom, lineWidth: 2)
                        .frame(width: max(0, x(range.upperBound, width) - x(range.lowerBound, width)))
                        .offset(x: x(range.lowerBound, width))
                        .allowsHitTesting(false)
                    if let playhead {
                        Rectangle().fill(Color.ink)
                            .frame(width: 2)
                            .offset(x: x(playhead, width) - 1)
                            .allowsHitTesting(false)
                    }
                    handle(.start, width: width)
                    handle(.end, width: width)
                }
                .coordinateSpace(name: "trim")
            }
            .frame(height: height)
            HStack {
                Text(time(range.lowerBound))
                Spacer()
                Text("Drag the ends to trim").foregroundStyle(.tertiary)
                Spacer()
                Text(time(range.upperBound))
            }
            .font(.meta)
            .foregroundStyle(.secondary)
        }
        .task(id: data) {
            let data = data
            levels = await Task.detached { AudioService.levels(of: data, count: Self.bars) }.value
        }
    }

    /// Bars inside the kept part in the accent, the rest faded.
    private var waveform: some View {
        HStack(spacing: 2) {
            ForEach(0..<Self.bars, id: \.self) { i in
                let level = i < levels.count ? CGFloat(levels[i]) : 0
                let t = (Double(i) + 0.5) / Double(Self.bars) * duration
                Capsule()
                    .fill(range.contains(t) ? Color.darkroom : Color.rule)
                    .frame(maxWidth: .infinity)
                    .frame(height: max(3, level * (height - 12)))
            }
        }
        .frame(maxHeight: .infinity)
        .padding(.horizontal, 4)
        .allowsHitTesting(false)
    }

    private func handle(_ edge: Edge, width: CGFloat) -> some View {
        let value = edge == .start ? range.lowerBound : range.upperBound
        return Capsule()
            .fill(Color.darkroom)
            .frame(width: 10)
            .overlay(Capsule().fill(Color.onDarkroom).frame(width: 2, height: height / 3))
            .shadow(color: .shadow, radius: 2, y: 1)
            .frame(width: 32)
            .contentShape(Rectangle())
            .offset(x: x(value, width) - 16)
            .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("trim")).onChanged { drag in
                set(edge, to: Double(drag.location.x / max(width, 1)) * duration)
            })
            .accessibilityElement()
            .accessibilityLabel(edge == .start ? Text("Start") : Text("End"))
            .accessibilityValue(time(value))
            .accessibilityAdjustableAction { direction in
                set(edge, to: value + (direction == .increment ? Self.minimum : -Self.minimum))
            }
    }

    /// Moves one end, keeping at least `minimum` between them.
    private func set(_ edge: Edge, to t: TimeInterval) {
        switch edge {
        case .start: range = min(max(0, t), range.upperBound - Self.minimum)...range.upperBound
        case .end: range = range.lowerBound...max(min(duration, t), range.lowerBound + Self.minimum)
        }
    }

    private func x(_ t: TimeInterval, _ width: CGFloat) -> CGFloat {
        duration > 0 ? CGFloat(t / duration) * width : 0
    }

    private func time(_ t: TimeInterval) -> String {
        Duration.seconds(t).formatted(.time(pattern: .minuteSecond(padMinuteToLength: 1, fractionalSecondsLength: 1)))
    }
}
