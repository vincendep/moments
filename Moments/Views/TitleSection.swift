import SwiftUI

/// Title field, the headline of an entry's screens, set in the serif straight on the page.
/// An empty title shows the entry's date, so that is the placeholder.
struct TitleSection: View {
    @Binding var title: String
    /// What an empty title falls back to.
    let placeholder: String
    /// Set while the field has scrolled out of sight (for a screen that then shows the title in its bar).
    var scrolledAway: Binding<Bool>?

    var body: some View {
        Section {
            TextField(placeholder, text: $title).font(.titleField)
                // A form's rows appear and disappear as they scroll in and out of sight.
                .onAppear { scrolledAway?.wrappedValue = false }
                .onDisappear { scrolledAway?.wrappedValue = true }
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
    }
}

