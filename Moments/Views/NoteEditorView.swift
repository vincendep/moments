import SwiftUI

struct NoteEditorView: View {
    let timeline: Timeline
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var text = ""
    @State private var date = Date.now
    @State private var hasTime = true
    @State private var place: Place?
    @State private var locating = LocationService.isAuthorized

    var body: some View {
        NavigationStack {
            PaperForm {
                TitleSection(title: $title, placeholder: Entry.dateLabel(date, hasTime: hasTime))
                NotesSection(text: $text, minHeight: 160)
                WhenWhereSection(date: $date, hasTime: $hasTime, place: $place, locating: locating)
            }
            .task { await locate() }
            .navigationTitle("New Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let entry = Entry(timeline: timeline, date: date, hasTime: hasTime,
                                          title: title, text: text, place: place)
                        Arrival.mark(entry)
                        ctx.insert(entry)
                        dismiss()
                    }
                    .disabled(title.isEmpty && text.isEmpty)
                }
            }
        }
    }

    /// Fills in the current location, unless one was picked meanwhile.
    private func locate() async {
        let current = await LocationService.current()
        if place == nil { place = current }
        locating = false
    }
}
