import Foundation

struct BusRoute: Identifiable, Codable, Equatable {
    var id: String { "\(operatorType.rawValue)-\(routeCode)-\(bound)-\(serviceType ?? "")" }
    let operatorType: BusOperator
    let routeCode: String
    let bound: String
    let serviceType: String?
    let region: String?
    let originEn: String
    let originTc: String
    let originSc: String
    let destEn: String
    let destTc: String
    let destSc: String
    let dataTimestamp: String?

    var displayLabel: String {
        let dest = Locale.current.language.languageCode?.identifier == "zh" ? destTc : destEn
        return "\(routeCode) → \(dest)"
    }
}
