import MapKit
import SwiftUI

/// An entry's location: a small map with a postmark and the place's name, or "Add Location".
/// Opens `LocationPicker`.
struct LocationSection: View {
    @Binding var place: Place?
    /// While the current location is still being found for a new entry.
    var locating = false
    /// The entry's date, for the postmark; none in the editors, where there is no postmark yet.
    var date: Date?

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
                    if let date { Postmark(place: place.name, date: date).padding(.trailing, 10).padding(.top, 10) }
                }
                .allowsHitTesting(false)
                .listRowInsets(EdgeInsets())
                .accessibilityHidden(true)
            }
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
