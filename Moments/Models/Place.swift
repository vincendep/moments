import CoreLocation

/// Where an entry happened: a name to show and its coordinate. Stored on `Entry` as
/// `placeName`, `latitude` and `longitude`; read and set them together through `Entry.place`.
struct Place: Hashable {
    var name: String
    var latitude: Double
    var longitude: Double

    init(name: String, coordinate: CLLocationCoordinate2D) {
        self.name = name
        latitude = coordinate.latitude
        longitude = coordinate.longitude
    }

    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }

    /// "Golden Gate Park, San Francisco": the placemark's name, plus its town when that adds something.
    /// Nil when the placemark has neither.
    static func name(for placemark: CLPlacemark) -> String? {
        name(placemark.name, locality: placemark.locality)
    }

    /// The rule behind `name(for:)`: the name, plus the town unless the name already includes it.
    static func name(_ name: String?, locality: String?) -> String? {
        let parts = [name, locality].compactMap { $0 }
        guard let first = parts.first else { return nil }
        return parts.count > 1 && !first.contains(parts[1]) ? "\(first), \(parts[1])" : first
    }

    /// The coordinate as text, for places that couldn't be named.
    static func name(for coordinate: CLLocationCoordinate2D) -> String {
        "\(coordinate.latitude.formatted(.number.precision(.fractionLength(4)))), "
            + coordinate.longitude.formatted(.number.precision(.fractionLength(4)))
    }
}

extension Entry {
    /// The entry's location, or nil when it has none.
    var place: Place? {
        get {
            guard let latitude, let longitude else { return nil }
            return Place(name: placeName, coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
        }
        set {
            latitude = newValue?.latitude
            longitude = newValue?.longitude
            placeName = newValue?.name ?? ""
        }
    }
}
