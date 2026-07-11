import SwiftUI
import Observation
import CoreLocation
import MapKit

@MainActor
@Observable
final class RouteDetailViewModel {
    let route: BusRoute

    var stopDetails: [StopDetail] = []
    var expandedSeq: Int? = nil
    var polylineCoords: [CLLocationCoordinate2D] = []
    var isLoading = false
    var errorMessage: String?
    var mapPosition: MapCameraPosition = .automatic

    private let client = KMBAPIClient()
    private let decoder = JSONDecoder()

    struct StopDetail: Identifiable {
        var id: Int { seq }
        let seq: Int
        let stopId: String
        let nameEn: String
        let nameTc: String
        let nameSc: String
        let coordinate: CLLocationCoordinate2D
        var etas: [ArrivalETA]

        var displayName: String {
            LanguageHelper.stopName(en: nameEn, tc: nameTc, sc: nameSc)
        }
    }

    init(route: BusRoute) {
        self.route = route
    }

    func load() async {
        isLoading = true
        errorMessage = nil

        do {
            let routeStopPairs = try await fetchFilteredRouteStops()
            guard !routeStopPairs.isEmpty else {
                errorMessage = "No stop data for this route"
                isLoading = false
                return
            }

            let stopLookup = try await buildStopLookup()

            stopDetails = routeStopPairs.compactMap { (seq, stopId) in
                guard let stop = stopLookup[stopId] else { return nil }
                return StopDetail(
                    seq: seq, stopId: stopId,
                    nameEn: stop.nameEn, nameTc: stop.nameTc, nameSc: stop.nameSc,
                    coordinate: stop.coordinate, etas: []
                )
            }

            if stopDetails.count > 1 {
                await loadRoutePolyline()
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func loadRoutePolyline() async {
        let count = stopDetails.count
        guard count > 1 else { return }
        var allCoords: [CLLocationCoordinate2D] = []

        await withThrowingTaskGroup(of: (Int, [CLLocationCoordinate2D])?.self) { group in
            for i in 0..<(count - 1) {
                let from = stopDetails[i].coordinate
                let to = stopDetails[i + 1].coordinate
                group.addTask {
                    if let coords = try? await self.routeSegment(from: from, to: to) {
                        return (i, coords)
                    }
                    return nil
                }
            }

            var segments = [(Int, [CLLocationCoordinate2D])]()
            do {
                for try await result in group {
                    if let (idx, coords) = result { segments.append((idx, coords)) }
                }
            } catch {}

            segments.sort { $0.0 < $1.0 }

            for (_, coords) in segments {
                if allCoords.isEmpty {
                    allCoords = coords
                } else {
                    allCoords.append(contentsOf: coords.dropFirst())
                }
            }
        }

        if !allCoords.isEmpty {
            polylineCoords = allCoords
        } else {
            polylineCoords = stopDetails.map(\.coordinate)
        }
    }

    private func routeSegment(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) async throws -> [CLLocationCoordinate2D] {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: from))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: to))
        request.transportType = .automobile

        let directions = MKDirections(request: request)
        let response = try await directions.calculate()
        guard let route = response.routes.first else { return [] }

        var coords = route.polyline.coordinates
        if coords.isEmpty { return [] }

        let first = coords[0]
        let last = coords[coords.count - 1]

        if distance(from: first, to: from) > distance(from: last, to: from) {
            coords.reverse()
        }

        return coords
    }

    private func distance(from a: CLLocationCoordinate2D, to b: CLLocationCoordinate2D) -> CLLocationDistance {
        let aLoc = CLLocation(latitude: a.latitude, longitude: a.longitude)
        let bLoc = CLLocation(latitude: b.latitude, longitude: b.longitude)
        return aLoc.distance(from: bLoc)
    }

    func selectStop(_ seq: Int) {
        if expandedSeq == seq {
            expandedSeq = nil
            return
        }
        expandedSeq = seq

        if let stop = stopDetails.first(where: { $0.seq == seq }) {
            withAnimation(.easeInOut(duration: 0.3)) {
                mapPosition = .region(MKCoordinateRegion(
                    center: stop.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                ))
            }
        }
    }

    func toggleStop(_ seq: Int) async {
        if expandedSeq == seq {
            expandedSeq = nil
            return
        }

        selectStop(seq)

        guard let index = stopDetails.firstIndex(where: { $0.seq == seq }) else { return }
        let stopId = stopDetails[index].stopId

        do {
            let data = try await client.fetchStopETA(stopId: stopId)
            let response = try decoder.decode(KMBResponse<[KMBETAData]>.self, from: data)
            let etas = response.data
                .filter { $0.route == route.routeCode && $0.dir == route.bound }
                .sorted { $0.etaSeq < $1.etaSeq }
                .prefix(3)
                .compactMap { raw -> ArrivalETA? in
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

            stopDetails = stopDetails.map { detail in
                if detail.seq == seq {
                    var copy = detail
                    copy.etas = etas
                    return copy
                }
                return detail
            }
        } catch {}
    }

    private func fetchFilteredRouteStops() async throws -> [(seq: Int, stopId: String)] {
        let data = try await client.fetchRouteStops()
        let response = try decoder.decode(KMBResponse<[KMBRouteStopData]>.self, from: data)
        return response.data
            .filter { $0.route == route.routeCode && $0.bound == route.bound && $0.serviceType == route.serviceType }
            .compactMap { pair in
                guard let seq = Int(pair.seq) else { return nil }
                return (seq: seq, stopId: pair.stop)
            }
            .sorted { $0.seq < $1.seq }
    }

    private func buildStopLookup() async throws -> [String: BusStop] {
        let data = try await client.fetchStops()
        let response = try decoder.decode(KMBResponse<[KMBStopData]>.self, from: data)
        var dict = [String: BusStop]()
        for raw in response.data {
            guard let lat = Double(raw.lat), let long = Double(raw.long) else { continue }
            dict[raw.stop] = BusStop(
                operatorType: .kmb, rawStopId: raw.stop,
                nameEn: raw.nameEn, nameTc: raw.nameTc, nameSc: raw.nameSc,
                latitude: lat, longitude: long,
                region: nil, dataTimestamp: nil
            )
        }
        return dict
    }
}

extension MKPolyline {
    var coordinates: [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: pointCount)
        getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
        return coords
    }
}
