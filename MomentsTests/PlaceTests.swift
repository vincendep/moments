import CoreLocation
import Testing
@testable import Moments

@MainActor
struct PlaceTests {
    @Test func entryPlaceRoundTrips() throws {
        let store = try TestStore()
        let e = store.entry(in: store.timeline())
        #expect(e.place == nil)

        let colosseum = Place(name: "Colosseum, Rome", coordinate: CLLocationCoordinate2D(latitude: 41.8902, longitude: 12.4922))
        e.place = colosseum
        #expect(e.place == colosseum)
        #expect(e.placeName == "Colosseum, Rome")

        e.place = nil
        #expect(e.place == nil)
        #expect(e.latitude == nil && e.longitude == nil)
        #expect(e.placeName == "")
    }

    @Test(arguments: [
        ("Golden Gate Park", "San Francisco", "Golden Gate Park, San Francisco"),
        ("Rome", "Rome", "Rome"),
        ("Piazza Navona, Rome", "Rome", "Piazza Navona, Rome"),
        (nil, "Rome", "Rome"),
        ("Somewhere", nil, "Somewhere"),
    ] as [(String?, String?, String)])
    func placeName(name: String?, locality: String?, expected: String) {
        #expect(Place.name(name, locality: locality) == expected)
    }

    @Test func noNameWithoutNameOrTown() {
        #expect(Place.name(nil, locality: nil) == nil)
    }

    @Test func coordinateNameHasFourDecimals() {
        let name = Place.name(for: CLLocationCoordinate2D(latitude: 41.890251, longitude: 12.492373))
        #expect(name == "41.8903, 12.4924")
    }
}
