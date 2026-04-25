import CoreLocation

final class LocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation?, Never>?
    private var timeoutWork: DispatchWorkItem?

    override init() {
        super.init()
        manager.delegate = self
    }

    func resolveCountryCode(for location: CLLocation) async -> String? {
        return await withCheckedContinuation { continuation in
            CLGeocoder().reverseGeocodeLocation(location) { placemarks, _ in
                continuation.resume(returning: placemarks?.first?.isoCountryCode?.uppercased())
            }
        }
    }

    func requestLocation() async -> CLLocation? {
        return await withCheckedContinuation { continuation in
            self.continuation = continuation

            switch manager.authorizationStatus {
            case .notDetermined:
                // Timeout starts only after the user grants permission (in delegate callback).
                manager.requestWhenInUseAuthorization()
            case .authorizedWhenInUse, .authorizedAlways:
                manager.requestLocation()
                scheduleTimeout()
            default:
                self.continuation = nil
                continuation.resume(returning: nil)
            }
        }
    }

    private func scheduleTimeout() {
        timeoutWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, let cont = self.continuation else { return }
            self.continuation = nil
            cont.resume(returning: nil)
        }
        timeoutWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 15, execute: work)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
            scheduleTimeout()  // Start 15s timeout only after permission is granted
        case .notDetermined:
            break
        default:
            guard let cont = continuation else { return }
            continuation = nil
            cont.resume(returning: nil)
        }
    }

    func locationManager(_ manager: CLLocationManager,
                         didUpdateLocations locations: [CLLocation]) {
        timeoutWork?.cancel()
        guard let cont = continuation else { return }
        continuation = nil
        cont.resume(returning: locations.first)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        timeoutWork?.cancel()
        guard let cont = continuation else { return }
        continuation = nil
        cont.resume(returning: nil)
    }
}
