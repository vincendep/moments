import SwiftUI

/// Title field, the headline of an entry's screens, set in the serif straight on the page.
/// An empty title shows the entry's date, so that is the placeholder.
struct TitleSection: View {
    @Binding var title: String
    /// What an empty title falls back to.
    let placeholder: String

    var body: some View {
        Section {
            TextField(placeholder, text: $title).font(.titleField)
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
    }
}
