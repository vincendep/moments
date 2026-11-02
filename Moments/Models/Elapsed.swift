import Foundation

enum Elapsed {
    /// e.g. "2 years, 3 months" or "5 months, 2 weeks", in the user's language; nil on the same day.
    static func string(from start: Date, to date: Date) -> String? {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: start, to: date)
        let y = c.year ?? 0, m = c.month ?? 0, d = c.day ?? 0
        var parts = DateComponents()
        if y > 0 {
            parts.year = y
            if m > 0 { parts.month = m }
        } else if m > 0 {
            parts.month = m
            if d >= 7 { parts.weekOfMonth = d / 7 }
        } else if d == 0 {
            return nil
        } else if d >= 7 {
            parts.weekOfMonth = d / 7
        } else {
            parts.day = d
        }
        return formatter.string(from: parts)
    }

    private static let formatter: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.unitsStyle = .full
        f.allowedUnits = [.year, .month, .weekOfMonth, .day]
        f.zeroFormattingBehavior = .dropAll
        return f
    }()
}
