import SwiftUI

/// Date with an optional time of day. Without a time, `date` is kept at the start of the day.
struct DateTimeSection: View {
    @Binding var date: Date
    @Binding var hasTime: Bool
    var footer: String?

    var body: some View {
        Section {
            DatePicker("Date", selection: $date, displayedComponents: .date)
            Toggle("Include time", isOn: $hasTime.animation())
            if hasTime {
                DatePicker("Time", selection: $date, displayedComponents: .hourAndMinute)
            }
        } footer: {
            if let footer { Text(footer) }
        }
        .onChange(of: hasTime) { _, on in
            if !on { date = Calendar.current.startOfDay(for: date) }
        }
        .onChange(of: date) { _, d in
            // The date picker keeps the old time of day; snap back when there is no time.
            if !hasTime, d != Calendar.current.startOfDay(for: d) { date = Calendar.current.startOfDay(for: d) }
        }
    }
}
