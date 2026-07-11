import Foundation

struct ArrivalETA: Identifiable, Equatable {
    var id: String { "\(operatorType.rawValue)-\(routeCode)-\(stopId)-\(etaSeq)" }
    let operatorType: BusOperator
    let routeCode: String
    let stopId: String
    let destEn: String
    let destTc: String
    let destSc: String
    let remarkEn: String
    let remarkTc: String
    let remarkSc: String
    let etaSeq: Int
    let etaTime: Date?
    let minutesAwayOverride: Int?

    var minutesAway: Int? {
        if let override = minutesAwayOverride { return override }
        guard let etaTime else { return nil }
        return Int(etaTime.timeIntervalSinceNow / 60)
    }

    var destinationDisplay: String {
        Locale.current.language.languageCode?.identifier == "zh" ? destTc : destEn
    }

    var remarkDisplay: String? {
        let remark = Locale.current.language.languageCode?.identifier == "zh" ? remarkTc : remarkEn
        return remark.isEmpty ? nil : remark
    }
}
