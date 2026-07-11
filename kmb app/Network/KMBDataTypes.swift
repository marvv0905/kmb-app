import Foundation

struct KMBResponse<T: Decodable>: Decodable {
    let data: T
}

struct KMBRouteData: Decodable {
    let route: String
    let bound: String
    let serviceType: String?
    let origEn: String
    let origTc: String
    let origSc: String
    let destEn: String
    let destTc: String
    let destSc: String

    enum CodingKeys: String, CodingKey {
        case route, bound
        case serviceType = "service_type"
        case origEn = "orig_en"
        case origTc = "orig_tc"
        case origSc = "orig_sc"
        case destEn = "dest_en"
        case destTc = "dest_tc"
        case destSc = "dest_sc"
    }
}

struct KMBStopData: Decodable {
    let stop: String
    let nameEn: String
    let nameTc: String
    let nameSc: String
    let lat: String
    let long: String

    enum CodingKeys: String, CodingKey {
        case stop
        case nameEn = "name_en"
        case nameTc = "name_tc"
        case nameSc = "name_sc"
        case lat, long
    }
}

struct KMBRouteStopData: Decodable {
    let route: String
    let bound: String
    let serviceType: String?
    let seq: String
    let stop: String

    enum CodingKeys: String, CodingKey {
        case route, bound
        case serviceType = "service_type"
        case seq, stop
    }
}

struct KMBETAData: Decodable {
    let route: String
    let dir: String
    let destEn: String
    let destTc: String
    let destSc: String
    let etaSeq: Int
    let eta: String?
    let rmkEn: String
    let rmkTc: String
    let rmkSc: String

    enum CodingKeys: String, CodingKey {
        case route, dir
        case destEn = "dest_en"
        case destTc = "dest_tc"
        case destSc = "dest_sc"
        case etaSeq = "eta_seq"
        case eta
        case rmkEn = "rmk_en"
        case rmkTc = "rmk_tc"
        case rmkSc = "rmk_sc"
    }
}

struct KMBRouteETAData: Decodable {
    let route: String
    let dir: String
    let serviceType: Int
    let seq: Int
    let destEn: String
    let destTc: String
    let destSc: String
    let etaSeq: Int
    let eta: String?
    let rmkEn: String
    let rmkTc: String
    let rmkSc: String

    enum CodingKeys: String, CodingKey {
        case route, dir
        case serviceType = "service_type"
        case seq
        case destEn = "dest_en"
        case destTc = "dest_tc"
        case destSc = "dest_sc"
        case etaSeq = "eta_seq"
        case eta
        case rmkEn = "rmk_en"
        case rmkTc = "rmk_tc"
        case rmkSc = "rmk_sc"
    }
}
