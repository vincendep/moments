import MapKit
import SwiftUI

/// When and where, in one section: a small map with a postmark (once there is a place), the date with
/// its time beside it, and the place's name or "Add Location", which opens `LocationPicker`.
/// Shared by an entry's details and the note and voice editors.
struct WhenWhereSection: View {
    @Binding var date: Date
    @Binding var hasTime: Bool
    @Binding var place: Place?
    /// While the current location is still being found for a new entry.
    var locating = false
    /// Stamps the postmark on the map; none in the editors, where there is no postmark yet.
    var postmarkDate: Date?

    var body: some View {
        Section {
            if let place {
                Map(initialPosition: .region(MKCoordinateRegion(center: place.coordinate,
                                                                latitudinalMeters: 1500, longitudinalMeters: 1500))) {
                    // Untitled: the row below names the place.
                    Marker("", coordinate: place.coordinate).tint(.darkroom)
                }
                .id(place)
                .saturation(0.7)
                .frame(height: 140)
                .overlay(alignment: .topTrailing) {
                    if let postmarkDate {
                        Postmark(place: place.name, date: postmarkDate).padding(.trailing, 10).padding(.top, 10)
                    }
                }
                .allowsHitTesting(false)
                .listRowInsets(EdgeInsets())
                .accessibilityHidden(true)
            }
            DateTimeRow(date: $date, hasTime: $hasTime)
            NavigationLink {
                LocationPicker(place: $place)
            } label: {
                if let place {
                    Label { Text(place.name) } icon: { Image("icon.postmark").foregroundStyle(.postmark) }
                } else if locating {
                    HStack {
                        Label("Finding Location…", systemImage: "location")
                        Spacer()
                        ProgressView()
                    }
                } else {
                    Label { Text("Add Location") } icon: { Image("icon.postmark") }
                }
            }
        }
    }
}
