import MapKit
import SwiftUI

/// Picks an entry's location: the current one, a searched place, or none.
struct LocationPicker: View {
    @Binding var place: Place?
    @Environment(\.dismiss) private var dismiss
    @State private var search = PlaceSearch()
    @State private var locating = false

    var body: some View {
        PaperForm {
            if search.query.isEmpty {
                Section {
                    if LocationService.isAuthorized {
                        Button(action: useCurrent) {
                            HStack {
                                Label("Current Location", systemImage: "location.fill")
                                Spacer()
                                if locating { ProgressView() }
                            }
                        }
                        .disabled(locating)
                    }
                    if place != nil {
                        Button("Remove Location", systemImage: "mappin.slash", role: .destructive) {
                            place = nil
                            dismiss()
                        }
                    }
                }
            }
            Section {
                ForEach(search.results, id: \.self) { completion in
                    Button { choose(completion) } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            // Color, not the hierarchical styles, which a button resolves against the tint.
                            Text(completion.title).foregroundStyle(Color.primary)
                            if !completion.subtitle.isEmpty {
                                Text(completion.subtitle).font(.subheadline).foregroundStyle(Color.secondary)
                            }
                        }
                    }
                }
            }
        }
        .searchable(text: $search.query, placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Search for a place")
        .navigationTitle("Location")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func useCurrent() {
        locating = true
        Task {
            if let current = await LocationService.current() {
                place = current
                dismiss()
            }
            locating = false
        }
    }

    private func choose(_ completion: MKLocalSearchCompletion) {
        Task {
            guard let item = try? await MKLocalSearch(request: MKLocalSearch.Request(completion: completion))
                .start().mapItems.first else { return }
            let coordinate = item.placemark.coordinate
            place = Place(name: Place.name(for: item.placemark) ?? completion.title, coordinate: coordinate)
            dismiss()
        }
    }
}

/// Place suggestions from Apple Maps as the query is typed.
@Observable
private final class PlaceSearch: NSObject, MKLocalSearchCompleterDelegate {
    var query = "" {
        didSet {
            if query.isEmpty { results = [] } else { completer.queryFragment = query }
        }
    }
    private(set) var results: [MKLocalSearchCompletion] = []
    @ObservationIgnored private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.resultTypes = [.address, .pointOfInterest]
        completer.delegate = self
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        results = query.isEmpty ? [] : completer.results
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        results = []
    }
}
