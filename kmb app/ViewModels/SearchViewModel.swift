import SwiftUI
import Observation

@MainActor
@Observable
final class SearchViewModel {
    var inputText = ""
    var searchResults: [BusRoute] = []
    var allRoutes: [BusRoute] = []
    var isLoadingRoutes = false

    private var loadTask: Task<Void, Never>?

    let numericKeys: [[String]] = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        ["0"]
    ]

    let letterKeys: [[String]] = [
        ["A", "B"],
        ["C", "E"],
        ["F", "K"],
        ["M", "N"],
        ["P", "R"],
        ["S", "W"],
        ["X"]
    ]

    init() {}

    func loadRoutesFromDB() {
        guard allRoutes.isEmpty else { return }
        loadTask?.cancel()
        loadTask = Task { [weak self] in
            guard let self else { return }
            isLoadingRoutes = true
            print("[Search] Fetching routes from API...")
            await fetchFromAPI()
            print("[Search] API returned \(allRoutes.count) routes")
            isLoadingRoutes = false
            if !inputText.isEmpty { search() }
        }
    }

    private func fetchFromAPI() async {
        let client = KMBAPIClient()
        let decoder = JSONDecoder()
        do {
            let data = try await client.fetchRoutes()
            let response = try decoder.decode(KMBResponse<[KMBRouteData]>.self, from: data)
            allRoutes = response.data.map { raw in
                BusRoute(operatorType: .kmb, routeCode: raw.route, bound: raw.bound, serviceType: raw.serviceType, region: nil, originEn: raw.origEn, originTc: raw.origTc, originSc: raw.origSc, destEn: raw.destEn, destTc: raw.destTc, destSc: raw.destSc, dataTimestamp: nil)
            }
            print("[Search] First 3 route codes: \(allRoutes.prefix(3).map(\.routeCode))")
        } catch {
            print("[Search] API fetch failed: \(error)")
            allRoutes = []
        }
    }

    func appendDigit(_ digit: String) {
        inputText += digit
        search()
    }

    func appendLetter(_ letter: String) {
        inputText += letter
        search()
    }

    func backspace() {
        guard !inputText.isEmpty else { return }
        inputText.removeLast()
        search()
    }

    func clearAll() {
        inputText = ""
        searchResults = []
    }

    private func search() {
        guard !inputText.isEmpty else {
            searchResults = []
            return
        }
        if allRoutes.isEmpty {
            loadRoutesFromDB()
            return
        }
        let q = inputText.uppercased()
        print("[Search] Sample codes: \(allRoutes.prefix(10).map { "«\($0.routeCode)»" })")
        searchResults = allRoutes
            .filter { $0.routeCode.uppercased().hasPrefix(q) }
            .sorted { $0.routeCode.localizedStandardCompare($1.routeCode) == .orderedAscending }
        print("[Search] Found \(searchResults.count) results for '\(q)'")
    }
}
