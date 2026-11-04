import SwiftUI

/// The date with the time of day beside it. The time is optional: the clock button sets one (now's time
/// of day) and the clear button drops it, keeping `date` at the start of the day.
struct DateTimeRow: View {
    @Binding var date: Date
    @Binding var hasTime: Bool

    var body: some View {
        HStack(spacing: 8) {
            Label { Text("Date") } icon: { Image(systemName: "calendar") }
                .lineLimit(1)
                .layoutPriority(-1)
            Spacer(minLength: 0)
            DatePicker("Date", selection: $date, displayedComponents: .date).labelsHidden()
            if hasTime {
                DatePicker("Time", selection: $date, displayedComponents: .hourAndMinute).labelsHidden()
                Button {
                    withAnimation { hasTime = false }
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Remove Time")
            } else {
                Button(action: addTime) {
                    Image(systemName: "clock").frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Add Time")
            }
        }
        .onChange(of: hasTime) { _, on in
            if !on { date = Calendar.current.startOfDay(for: date) }
        }
        .onChange(of: date) { _, d in
            // The date picker keeps the old time of day; snap back when there is no time.
            if !hasTime, d != Calendar.current.startOfDay(for: d) { date = Calendar.current.startOfDay(for: d) }
        }
    }

    /// Gives the day the current time of day, rather than midnight.
    private func addTime() {
        let now = Calendar.current.dateComponents([.hour, .minute], from: .now)
        date = Calendar.current.date(bySettingHour: now.hour ?? 12, minute: now.minute ?? 0, second: 0, of: date) ?? date
        withAnimation { hasTime = true }
    }
}
