import SwiftUI

/// A month's heading in the timeline: the month in italic ink, the year in grey, both in the serif.
/// The month is formatted standalone, so languages that lowercase it mid-sentence (Italian) capitalise it here.
struct MonthHeader: View {
    let month: Date

    var body: some View {
        Text("\(Text(month.formatted(Date.FormatStyle(capitalizationContext: .standalone).month(.wide))).font(.month)) \(Text(month.formatted(.dateTime.year())).font(.monthYear).foregroundStyle(Color.secondary))")
            // Explicit colours: inside a section header .primary would resolve to the header's grey.
            .foregroundStyle(Color.ink)
            .textCase(nil)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}
