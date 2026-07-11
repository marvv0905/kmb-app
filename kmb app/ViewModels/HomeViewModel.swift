import Foundation
import Observation
import CoreLocation

@MainActor
@Observable
final class HomeViewModel: NSObject, CLLocationManagerDelegate {
    var nearbyStops: [StopWithETA] = []
    var isLoading = false
    var errorMessage: String?
    var isSyncing = false
    var syncError: String?
    var showPermissionPrompt: Bool
    var locationPermissionDenied = false

    private let database = AppDatabase.shared
    private let stopRepo: StopRepository
    private let client = KMBAPIClient()
    private let decoder = JSONDecoder()
    private let locationManager = CLLocationManager()

    private static let fallbackLocation = CLLocationCoordinate2D(latitude: 22.3193, longitude: 114.1694)

    struct StopWithETA: Identifiable {
        var id: String { "\(stop.operatorType.rawValue)-\(stop.rawStopId)" }
        let stop: BusStop
        let distance: Double
        var etas: [ArrivalETA]

        var displayName: String {
            LanguageHelper.stopName(en: stop.nameEn, tc: stop.nameTc, sc: stop.nameSc)
        }

        var distanceDisplay: String {
            "\(Int(distance))m"
        }
    }

    override init() {
        stopRepo = StopRepository(database: database)
        let status = CLLocationManager().authorizationStatus
        showPermissionPrompt = (status == .notDetermined || status == .denied)
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func start() async {
        await syncIfNeeded()
        await refreshStops()
    }

    func requestPermission() {
        showPermissionPrompt = false
        locationManager.requestWhenInUseAuthorization()
    }

    func useWithoutLocation() {
        showPermissionPrompt = false
        locationPermissionDenied = true
        Task { await refreshStops() }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            locationPermissionDenied = false
            manager.requestLocation()
        case .denied, .restricted:
            locationPermissionDenied = true
        default:
            break
        }
        Task { await refreshStops() }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task {
            await refreshStops()
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationPermissionDenied = true
    }

    private func syncIfNeeded() async {
        let metaRepo = SyncMetaRepository(database: database)
        let routeRepo = RouteRepository(database: database)
        let key = "kmb_static_data_last_synced"
        let interval: TimeInterval = 86_400

        if let last = try? await metaRepo.lastSyncTimestamp(for: key),
           Date().timeIntervalSince(last) < interval { return }

        isSyncing = true
        syncError = nil
        do {
            let client = KMBAPIClient()
            let decoder = JSONDecoder()

            let stopData = try await client.fetchStops()
            let stops = try decoder.decode(KMBResponse<[KMBStopData]>.self, from: stopData).data.compactMap { raw -> BusStop? in
                guard let lat = Double(raw.lat), let long = Double(raw.long) else { return nil }
                return BusStop(operatorType: .kmb, rawStopId: raw.stop, nameEn: raw.nameEn, nameTc: raw.nameTc, nameSc: raw.nameSc, latitude: lat, longitude: long, region: nil, dataTimestamp: nil)
            }
            try await stopRepo.upsertStops(stops)

            let routeData = try await client.fetchRoutes()
            let routes = try decoder.decode(KMBResponse<[KMBRouteData]>.self, from: routeData).data.map { raw in
                BusRoute(operatorType: .kmb, routeCode: raw.route, bound: raw.bound, serviceType: raw.serviceType, region: nil, originEn: raw.origEn, originTc: raw.origTc, originSc: raw.origSc, destEn: raw.destEn, destTc: raw.destTc, destSc: raw.destSc, dataTimestamp: nil)
            }
            try await routeRepo.upsertRoutes(routes)

            let rsData = try await client.fetchRouteStops()
            let pairs = try decoder.decode(KMBResponse<[KMBRouteStopData]>.self, from: rsData).data
            try await routeRepo.upsertAllRouteStops(operator: .kmb, pairs: pairs)

            try await metaRepo.setSyncTimestamp(Date(), for: key)
        } catch {
            syncError = error.localizedDescription
        }
        isSyncing = false
    }

    func refreshStops() async {
        isLoading = true
        errorMessage = nil
        do {
            let allStops = try await stopRepo.stopsForOperator(.kmb)
            let userLoc: CLLocationCoordinate2D
            let status = locationManager.authorizationStatus
            if status == .authorizedWhenInUse || status == .authorizedAlways,
               let loc = locationManager.location?.coordinate {
                userLoc = loc
            } else {
                userLoc = Self.fallbackLocation
            }

            let distanceToHK = haversine(from: userLoc, to: Self.fallbackLocation)
            let effectiveLoc = distanceToHK > 5000 ? Self.fallbackLocation : userLoc

            let withDistances: [(BusStop, Double)] = allStops.map { stop in
                (stop, haversine(from: effectiveLoc, to: stop.coordinate))
            }

            let nearby = withDistances
                .filter { $0.1 <= 500 }
                .sorted { $0.1 < $1.1 }

            nearbyStops = nearby.map { StopWithETA(stop: $0.0, distance: $0.1, etas: []) }
            await fetchETAsForNearbyStops()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func fetchETAsForNearbyStops() async {
        for i in nearbyStops.indices {
            let stopId = nearbyStops[i].stop.rawStopId
            do {
                let data = try await client.fetchStopETA(stopId: stopId)
                let response = try decoder.decode(KMBResponse<[KMBETAData]>.self, from: data)
                nearbyStops[i].etas = response.data.compactMap { raw in
                    let etaTime: Date?
                    if let etaStr = raw.eta, !etaStr.isEmpty {
                        etaTime = ISO8601DateFormatter().date(from: etaStr)
                    } else { etaTime = nil }
                    return ArrivalETA(
                        operatorType: .kmb, routeCode: raw.route, stopId: stopId,
                        destEn: raw.destEn, destTc: raw.destTc, destSc: raw.destSc,
                        remarkEn: raw.rmkEn, remarkTc: raw.rmkTc, remarkSc: raw.rmkSc,
                        etaSeq: raw.etaSeq, etaTime: etaTime, minutesAwayOverride: nil
                    )
                }
            } catch {}
        }
    }

    func etaPollingLoop() async {
        while !Task.isCancelled {
            await fetchETAsForNearbyStops()
            try? await Task.sleep(for: .seconds(25))
        }
    }
}

private func haversine(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
    let R: Double = 6371000
    let dLat = (to.latitude - from.latitude) * .pi / 180
    let dLon = (to.longitude - from.longitude) * .pi / 180
    let a = sin(dLat / 2) * sin(dLat / 2)
        + cos(from.latitude * .pi / 180) * cos(to.latitude * .pi / 180)
        * sin(dLon / 2) * sin(dLon / 2)
    let c = 2 * atan2(sqrt(a), sqrt(1 - a))
    return R * c
}
