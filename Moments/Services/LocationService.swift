import CoreLocation

/// Location access and the phone's current place. Access is asked for once, when an add sheet
/// first opens; the answer is the only switch: with it, new entries get the current location.
@MainActor
final class LocationService: NSObject, CLLocationManagerDelegate {
    private static let shared = LocationService()
    private let manager = CLLocationManager()
    private var accessWaiters: [CheckedContinuation<Bool, Never>] = []
    private var locationWaiters: [CheckedContinuation<CLLocation?, Never>] = []

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    static var isAuthorized: Bool {
        let status = shared.manager.authorizationStatus
        return status == .authorizedWhenInUse || status == .authorizedAlways
    }

    /// Shows the system prompt the first time, then returns the stored answer without asking again.
    @discardableResult
    static func requestAccess() async -> Bool {
        let s = shared
        if s.manager.authorizationStatus == .notDetermined {
            _ = await withCheckedContinuation { cont in
                s.accessWaiters.append(cont)
                if s.accessWaiters.count == 1 { s.manager.requestWhenInUseAuthorization() }
            }
        }
        return isAuthorized
    }

    /// The phone's location, or nil without access or when none arrives. Never prompts.
    static func currentLocation() async -> CLLocation? {
        guard isAuthorized else { return nil }
        let s = shared
        return await withCheckedContinuation { cont in
            s.locationWaiters.append(cont)
            if s.locationWaiters.count == 1 { s.manager.requestLocation() }
        }
    }

    /// The current location, named. Nil without access.
    static func current() async -> Place? {
        guard let location = await currentLocation() else { return nil }
        return await place(for: location)
    }

    /// Names a location through Apple's geocoder, falling back to its coordinate.
    static func place(for location: CLLocation) async -> Place {
        let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first
        let name = placemark.flatMap(Place.name(for:)) ?? Place.name(for: location.coordinate)
        return Place(name: name, coordinate: location.coordinate)
    }

    // The manager calls back on the main thread, where it was created.

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        MainActor.assumeIsolated {
            // Also called right after the delegate is set, before any answer.
            guard manager.authorizationStatus != .notDetermined else { return }
            accessWaiters.forEach { $0.resume(returning: Self.isAuthorized) }
            accessWaiters = []
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        MainActor.assumeIsolated { finishLocating(locations.last) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        MainActor.assumeIsolated { finishLocating(nil) }
    }

    private func finishLocating(_ location: CLLocation?) {
        locationWaiters.forEach { $0.resume(returning: location) }
        locationWaiters = []
    }
}
