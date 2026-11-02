import Foundation

extension Timeline {
    /// The timeline's milestone entries, oldest first.
    var milestones: [Entry] { sortedEntries.reversed().filter(\.isMilestone) }
}

extension Entry {
    /// The time between `previous` and this entry, for the line joining milestones.
    func interval(since previous: Entry) -> String {
        Elapsed.string(from: previous.date, to: date) ?? String(localized: "Same day")
    }

    /// For the milestones view: "Start" for the timeline's first milestone, otherwise the time since it.
    func sinceFirstMilestone(_ first: Entry) -> String {
        if first.id == id { return String(localized: "Start") }
        return Elapsed.string(from: first.date, to: date) ?? String(localized: "Same day")
    }
}
