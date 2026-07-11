import Foundation
import CoreLocation

struct BusStop: Identifiable, Codable, Equatable {
    var id: String { "\(operatorType.rawValue)-\(rawStopId)" }
    let operatorType: BusOperator
    let rawStopId: String
    let nameEn: String
    let nameTc: String
    let nameSc: String
    let latitude: Double
    let longitude: Double
    let region: String?
    let dataTimestamp: String?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
