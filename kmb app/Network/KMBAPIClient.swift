import Foundation

final class KMBAPIClient {
    private let baseURL = "https://data.etabus.gov.hk"
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 120
        session = URLSession(configuration: config)
    }

    func fetchRoutes() async throws -> Data {
        try await get("/v1/transport/kmb/route/")
    }

    func fetchStops() async throws -> Data {
        try await get("/v1/transport/kmb/stop")
    }

    func fetchRouteStops() async throws -> Data {
        try await get("/v1/transport/kmb/route-stop/")
    }

    func fetchStopETA(stopId: String) async throws -> Data {
        try await get("/v1/transport/kmb/stop-eta/\(stopId)")
    }

    func fetchRouteETA(route: String, serviceType: String) async throws -> Data {
        try await get("/v1/transport/kmb/route-eta/\(route)/\(serviceType)")
    }

    private func get(_ path: String) async throws -> Data {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw KMBError.invalidURL
        }
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw KMBError.invalidResponse
        }
        switch httpResponse.statusCode {
        case 200:
            return data
        case 404, 422:
            throw KMBError.notFound
        case 500:
            throw KMBError.serverError
        default:
            throw KMBError.httpError(httpResponse.statusCode)
        }
    }
}

enum KMBError: LocalizedError {
    case invalidURL
    case invalidResponse
    case notFound
    case serverError
    case httpError(Int)
    case decodingError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .invalidResponse: return "Invalid server response"
        case .notFound: return "Route or stop not found"
        case .serverError: return "Server error, please try again"
        case .httpError(let code): return "HTTP error \(code)"
        case .decodingError(let msg): return "Data error: \(msg)"
        }
    }
}
