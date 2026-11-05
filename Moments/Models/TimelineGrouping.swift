import Foundation

extension Timeline {
    /// Consecutive entries grouped by the start of their month, newest first (the All tab's sections).
    var entriesByMonth: [(Date, [Entry])] {
        var groups: [(Date, [Entry])] = []
        for e in sortedEntries {
            let month = Calendar.current.dateInterval(of: .month, for: e.date)?.start ?? e.date
            if groups.last?.0 == month { groups[groups.count - 1].1.append(e) } else { groups.append((month, [e])) }
        }
        return groups
    }

    /// One item per day with entries, newest first, pointing at that day's first row (for `DayScrubber`).
    var scrubberDays: [ScrubberDay] {
        var days: [ScrubberDay] = []
        for e in sortedEntries {
            let day = Calendar.current.startOfDay(for: e.date)
            if days.last?.date != day {
                days.append(ScrubberDay(date: day, entryID: e.id, isMilestone: e.isMilestone))
            } else if e.isMilestone {
                days[days.count - 1].isMilestone = true
            }
        }
        return days
    }
}
