# Technical Requirements Document (TRD)
## Ad-Free Multi-Operator Bus ETA App for iOS

**Author:** Rosario Justin
**Version:** 0.3 (Draft)
**Date:** July 11, 2026
**Status:** Draft for review
**Companion to:** KMB_ETA_iOS_App_PRD.md v0.3
**Changelog from v0.2:** Replaced the walk+wait+ride+walk travel-time algorithm with an in-vehicle bus travel time estimator derived from live ETA data between two stops on the same route; MKDirections removed from core tech stack as it's no longer required.

---

## 1. Purpose & Scope

This TRD translates the PRD's functional requirements into concrete technical specifications: system architecture, data models, API contracts per operator, normalization strategy, algorithms, and infrastructure needed to build v0.1-v0.3 of the app across KMB, CTB, and GMB.

---

## 2. System Architecture

### 2.1 High-Level Diagram (textual)

```
[KMB API]      [CTB API]      [GMB API]
     |              |              |
     v              v              v
[KMBAdapter]  [CTBAdapter]  [GMBAdapter]   <- each conforms to BusDataSource protocol
     \\              |              /
      \\-------------|-------------/
                     v
          [Unified Repository Layer]
                     |
                     v
       [Local Store: SQLite via GRDB]
                     |
                     v
         [ViewModel Layer (@Observable)]
                     |
                     v
  [SwiftUI Views: Map, Search, Stop Detail, Favorites]
                     |
                     v
        [MapKit: Map, Marker]
```

### 2.2 Layers

| Layer | Responsibility | Key Types |
|---|---|---|
| Network (per operator) | Raw HTTP calls, decoding each operator's native JSON schema | KMBAPIClient, CTBAPIClient, GMBAPIClient |
| Adapter | Maps each operator's raw response into shared domain models | KMBAdapter, CTBAdapter, GMBAdapter (all conform to BusDataSource) |
| Repository | Orchestrates cache-vs-network across all adapters, exposes unified domain models | RouteRepository, StopRepository, ETARepository |
| Persistence | Local SQLite cache of static data (tagged by operator) + last-known ETA snapshot | AppDatabase (GRDB), migration scripts |
| Domain/ViewModel | Business logic: cross-operator search matching, travel-time calc, favorites | MapViewModel, SearchViewModel, TravelTimeEstimator |
| Presentation | SwiftUI views, MapKit integration | MapView, StopDetailSheet, SearchView, RouteDetailView |

### 2.3 Tech Stack

- **Language:** Swift 6
- **UI:** SwiftUI, MapKit (native Map view, Marker)
- **Min iOS:** 17.0
- **Persistence:** GRDB.swift (SQLite wrapper)
- **Concurrency:** Swift async/await + Task groups for parallel per-operator static-data fetches
- **Dependency management:** Swift Package Manager
- **Testing:** Swift Testing for unit tests; XCTest for UI tests (XCUITest cannot use Swift Testing)

### 2.4 MapKit Setup - Clarified Requirements

Displaying the map and stop annotations requires **no API key, no Apple Developer Program enrollment, and no "Maps" capability toggle**. A minimal working map is just:

```swift
import SwiftUI
import MapKit

struct MapScreen: View {
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 22.3193, longitude: 114.1694),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    )
    var body: some View {
        Map(position: $position) {
            // Marker/Annotation per stop added here
        }
    }
}
```

- The Xcode "Maps" capability is only required if the app registers as a system-wide routing/navigation provider - out of scope for this project, so it is NOT needed.
- NSLocationWhenInUseUsageDescription in Info.plist IS required, but only once CLLocationManager is used to obtain the live user-location dot; it is not needed for the static map itself.
- MKDirections is not required for the in-vehicle travel time estimator (Section 5.3), which is derived from operator ETA data instead. It remains available if a future walk-to-stop distance feature is added.
- Apple Developer Program enrollment ($99/year) is only needed for App Store distribution or push notifications, not for MapKit functionality or personal device testing.

---

## 3. Data Model

### 3.1 Per-Operator Remote API Contracts

**KMB / LWB** (base: https://data.etabus.gov.hk/)

| Model | Key Fields | Source Endpoint |
|---|---|---|
| Route | co, route, bound (I/O), service_type, orig_en/tc/sc, dest_en/tc/sc | /v1/transport/kmb/route/ |
| Stop | stop (16-char hex ID), name_en/tc/sc, lat, long | /v1/transport/kmb/stop |
| RouteStop | co, route, bound, service_type, seq, stop | /v1/transport/kmb/route-stop/ |
| ETA | route, dir, service_type, seq, stop, dest_en, eta_seq, eta (absolute ISO8601, up to 3), rmk_en | /v1/transport/kmb/stop-eta/{stop_id} |

**CTB (Citybus)** (base: https://rt.data.gov.hk/v2/transport/citybus/)

| Model | Key Fields | Source Endpoint |
|---|---|---|
| Company | co (always CTB), name_en/tc/sc, url | /company/{companyid} |
| Route | co, route, orig_en/tc/sc, dest_en/tc/sc | /route/{companyid}/{route} |
| Stop | stop (6-digit zero-padded ID), name_en/tc/sc, lat, long | /stop/{stopid} |
| RouteStop | co, route, dir (I/O), seq, stop | /route-stop/{companyid}/{route}/{direction} |
| ETA | co, route, dir, seq, stop, dest_en, eta_seq, eta (absolute ISO8601, up to 3), rmk_en | /eta/{companyid}/{stopid}/{route} |

Note: CTB's ETA endpoint requires route as a path parameter - there is no single "all routes at this stop" shortcut like KMB's stop-eta. To populate a stop's full board, the app must call /eta/CTB/{stopid}/{route} once per route known to serve that stop (from cached route-stop data). CTB also explicitly returns HTTP 429 when over-polled.

**GMB (Green Minibus)** (base: https://data.etagmb.gov.hk/)

| Model | Key Fields | Source Endpoint |
|---|---|---|
| Route (regional) | region (HKI/KLN/NT), route_code (unique only within region), route_id | /route/{region} or /route/{region}/{routecode} |
| Route (by ID) | route_id, region, route_code, description_en/tc/sc, directions[] with route_seq, orig/dest | /route/{routeid} |
| Stop | stop_id (integer), coordinates.wgs84.latitude/longitude, enabled | /stop/{stopid} |
| RouteStop | route_id, route_seq, stop_seq, stop_id, name_en/tc/sc | /route-stop/{routeid}/{routeseq} |
| StopETA | route_id, route_seq, stop_seq, eta_seq, diff (relative minutes), timestamp (absolute), remark_en | /eta/stop/{stopid} |

Note: GMB uniquely provides both a relative-minutes (diff) and absolute-timestamp ETA field - use diff directly for UI display rather than recomputing from the timestamp, for consistency and simplicity. GMB's /eta/stop/{stopid} endpoint DOES return all routes at a stop in one call, similar to KMB's stop-eta.

### 3.2 Unified Domain Models (Swift)

```swift
enum BusOperator: String, Codable {
    case kmb, ctb, gmb
}

struct BusStop: Identifiable, Codable {
    var id: String { "\(operatorType.rawValue)-\(rawStopId)" }
    let operatorType: BusOperator
    let rawStopId: String       // operator-native ID format, stored as string regardless of source type
    let nameEn, nameTc, nameSc: String
    let coordinate: CLLocationCoordinate2D
    let region: String?         // GMB only: HKI/KLN/NT
}

struct BusRoute: Identifiable, Codable {
    var id: String { "\(operatorType.rawValue)-\(routeCode)-\(bound)-\(serviceType ?? "")" }
    let operatorType: BusOperator
    let routeCode: String       // KMB/CTB route number, or GMB route_code
    let bound: String           // "I"/"O", or GMB route_seq mapped to a bound-equivalent
    let serviceType: String?    // KMB only
    let region: String?         // GMB only
    let originEn, destEn: String
}

struct ArrivalETA: Identifiable {
    var id: String { "\(operatorType.rawValue)-\(routeCode)-\(stopId)-\(etaSeq)" }
    let operatorType: BusOperator
    let routeCode, stopId, destEn, remarkEn: String
    let etaSeq: Int
    let etaTime: Date?           // absolute time, nil if unavailable
    let minutesAwayOverride: Int? // GMB's native diff field, used directly when present
    var minutesAway: Int? {
        if let override = minutesAwayOverride { return override }
        guard let etaTime else { return nil }
        return Int(etaTime.timeIntervalSinceNow / 60)
    }
}
```

### 3.3 BusDataSource Protocol (Adapter Pattern)

```swift
protocol BusDataSource {
    var operatorId: BusOperator { get }
    func fetchAllRoutes() async throws -> [BusRoute]
    func fetchAllStops() async throws -> [BusStop]
    func fetchRouteStops(route: BusRoute) async throws -> [BusStop]
    func fetchStopETA(stopId: String) async throws -> [ArrivalETA]
}
```

Each of KMBAdapter, CTBAdapter, and GMBAdapter implements this protocol, internally calling their respective APIClient and mapping raw responses into BusRoute/BusStop/ArrivalETA. The Repository layer holds an array of [BusDataSource] and fans out calls across all three, merging results - this means adding a 4th operator later (e.g. NLB) only requires one new adapter, no changes to Repository/ViewModel/View layers.

Special handling required in CTBAdapter.fetchStopETA: since CTB has no all-routes-at-stop endpoint, this method must first look up cached routes serving that stop (from local route_stops table) and issue one /eta/CTB/{stopid}/{route} call per route, run concurrently via withThrowingTaskGroup.

### 3.4 Local SQLite Schema

```sql
CREATE TABLE routes (
    operator TEXT NOT NULL,        -- 'kmb' | 'ctb' | 'gmb'
    route_code TEXT NOT NULL,
    bound TEXT NOT NULL,
    service_type TEXT,             -- KMB only, NULL otherwise
    region TEXT,                   -- GMB only, NULL otherwise
    orig_en TEXT, orig_tc TEXT, orig_sc TEXT,
    dest_en TEXT, dest_tc TEXT, dest_sc TEXT,
    data_timestamp TEXT,
    PRIMARY KEY (operator, route_code, bound, service_type, region)
);

CREATE TABLE stops (
    operator TEXT NOT NULL,
    stop_id TEXT NOT NULL,         -- normalized to string regardless of source type
    name_en TEXT, name_tc TEXT, name_sc TEXT,
    lat REAL NOT NULL,
    long REAL NOT NULL,
    region TEXT,                   -- GMB only
    data_timestamp TEXT,
    PRIMARY KEY (operator, stop_id)
);

CREATE TABLE route_stops (
    operator TEXT NOT NULL,
    route_code TEXT NOT NULL,
    bound TEXT NOT NULL,
    service_type TEXT,
    seq INTEGER NOT NULL,
    stop_id TEXT NOT NULL,
    PRIMARY KEY (operator, route_code, bound, service_type, seq)
);

CREATE TABLE favorites (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    operator TEXT NOT NULL,
    stop_id TEXT NOT NULL,
    route_code TEXT,
    bound TEXT,
    label TEXT,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE recent_searches (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    query TEXT NOT NULL,
    searched_at TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE sync_meta (
    key TEXT PRIMARY KEY,          -- e.g. 'kmb_static_data_last_synced', 'ctb_static_data_last_synced'
    value TEXT
);

CREATE INDEX idx_stops_lat_long ON stops(lat, long);
CREATE INDEX idx_route_stops_stop_id ON route_stops(operator, stop_id);
```

Live ETA data is NOT persisted long-term; cached in-memory per session with a short TTL (~15-20s) keyed by (operator, stop_id).

---

## 4. API Integration Details

### 4.1 Base Configuration Per Operator

| Operator | Base URL | Auth | Notes |
|---|---|---|---|
| KMB/LWB | https://data.etabus.gov.hk/ | None | No documented rate limit |
| CTB | https://rt.data.gov.hk/v2/transport/citybus/ | None | Returns HTTP 429 on excessive requests |
| GMB | https://data.etagmb.gov.hk/ | None | No documented rate limit; route codes non-unique across regions |

### 4.2 Static Data Sync Job

- Triggered on: first app launch, or if the relevant sync_meta key is older than 24 hours (each operator synced independently, since update cadence isn't guaranteed identical).
- Sequence per operator: fetch Route List -> fetch Stop List -> fetch Route-Stop List -> bulk upsert into SQLite tagged with operator inside a single transaction per operator.
- Run via parallel background Tasks (one per operator) with withThrowingTaskGroup, so a failure/delay in one operator's sync doesn't block the others.

### 4.3 Live ETA Polling (Per Operator Strategy)

| Operator | Strategy |
|---|---|
| KMB | Single call to stop-eta/{stop_id} returns all routes at stop |
| GMB | Single call to eta/stop/{stopid} returns all routes at stop |
| CTB | Must call eta/{companyid}/{stopid}/{route} once per known route at that stop, run concurrently; implement exponential backoff on HTTP 429 |

- Poll interval: 20-30 seconds while StopDetailSheet is visible; polling stops when the sheet is dismissed or app backgrounds.
- Cancellation: use Task cancellation tied to view lifecycle (.task { } modifier) to avoid orphaned network calls.

### 4.4 Error Handling

| HTTP Code | Meaning | App Behavior |
|---|---|---|
| 200 | Success | Parse and display |
| 404 | Not found (GMB) | Log, show "Stop/route not found" |
| 422 | Client/param error (KMB, CTB) | Log, show "Route/stop not found" |
| 429 | Rate limited (CTB) | Exponential backoff retry; show cached data meanwhile |
| 500 | Server error | Retry once with backoff, then show cached data + "Live data unavailable" banner |
| Network timeout | No connectivity | Show cached static data; disable live ETA with offline indicator |

Each operator's failure is isolated - e.g. if CTB is rate-limited, KMB and GMB results for the same map view still render normally.

---

## 5. Feature-Level Technical Design

### 5.1 Map View

- Map (SwiftUI, iOS 17+ Map(position:) API) with Marker/Annotation per visible stop, color-coded by BusStop.operatorType.
- No Xcode "Maps" capability or API key required for this (see Section 2.4).
- Viewport-based query: only render stops within current visible map region (spatial filter on lat/long index) across all three operators' tables, merged client-side.
- Cluster below a zoom threshold using MapKit's built-in clustering.
- CLLocationManager (When-In-Use authorization) drives the user location dot; requires NSLocationWhenInUseUsageDescription in Info.plist.

### 5.2 Search

- Local search index built from cached stops and routes tables (all operators) using SQLite LIKE or FTS5 virtual table for fuzzy matching on name_en, name_tc, route_code.
- Results labeled by operator badge to disambiguate colliding route codes (notably GMB, where codes repeat across regions).
- Debounced search-as-you-type (300ms).

### 5.3 In-Vehicle Bus Travel Time Estimation

**Scope clarification:** this feature estimates the ride duration on a specific bus route between a boarding stop and an alighting stop (i.e. "how long will I be on this bus"), NOT a full multi-modal walk+wait+bus+walk journey planner. Walking legs to/from stops are out of scope for this calculation.

**Primary approach: derive from live Route ETA data (preferred, most accurate)**

Each operator's Route ETA endpoint (KMB `route-eta/{route}/{service_type}`, CTB per-route `eta`, GMB `eta/stop` aggregated per route) returns ETA times for a given upcoming bus across multiple stops along its sequence. Where the same bus "trip" can be identified across two stops (matched via `eta_seq` ordering and consistent `dest_en`/remarks for KMB/CTB, or the same GMB `eta_seq` entry per route_seq), the in-vehicle travel time between stop A (origin) and stop B (destination) is:

```
travel_time = eta_at_destination_stop - eta_at_origin_stop
```

This uses the operator's live-tracked or scheduled ETA data directly, so it reflects real-time traffic/delay conditions rather than a static average.

1. User selects a route and two stops on that route (origin/boarding stop, destination/alighting stop), confirmed to be in the correct sequence order (destination `seq` > origin `seq` for the route's bound/direction).
2. Fetch live ETA for both stops on that route (`stop-eta` or `route-eta` depending on operator).
3. Match corresponding upcoming trips between the two stops (by `eta_seq` order, assuming buses arrive at downstream stops in the same order they departed upstream stops).
4. Compute `travel_time = eta[destination] - eta[origin]` for each matched trip; average across the 2-3 available ETA entries per operator's typical response size for a smoothed estimate.
5. Display estimated in-vehicle time (e.g. "~14 min on this bus") alongside the live countdown for when the next bus departs the boarding stop.

**Fallback approach: stop-sequence heuristic (used when live ETA data is unavailable for one or both stops, e.g. late-night/low-frequency GMB routes)**

- `in_vehicle_time = stop_hop_count x average inter-stop time` (~1.5-2 min/stop; GMB minibuses may warrant a shorter average given typically shorter inter-stop distances - calibrate separately per operator in v2).
- `stop_hop_count` = difference in `seq` (KMB/CTB) or `stop_seq` (GMB) between origin and destination stops on the cached `route_stops` table.

**Note:** `MKDirections` and haversine-based walking-time calculations are NOT part of this feature - they were part of an earlier, broader "travel time to a destination" concept that has been descoped. If a full walk+wait+bus+walk journey planner is wanted later, it would be a separate v2 feature building on top of this in-vehicle estimator.

### 5.4 Favorites & Recents

- CRUD against favorites/recent_searches tables, each favorite tagged with its operator field to avoid ambiguity.

### 5.5 Notifications (v1: foreground only)

- In-app banner/badge when a favorited route (any operator) drops below a threshold ETA.
- v2 (stretch): CLCircularRegion geofencing + UNUserNotificationCenter, requiring "Always" location permission.

---

## 6. Non-Functional Implementation Notes

- **Performance budget:** Cold start to first map render < 1.5s; stop tap to ETA display < 1s per operator (CTB's per-route ETA calls may be the slowest path due to multiple concurrent requests - monitor separately).
- **Battery:** Polling only active while relevant view is on-screen; no background polling in v1.
- **Offline resilience:** Static data (all operators) available offline post first-sync; live ETA gracefully degrades per operator with "last updated Xs ago" timestamp.
- **Privacy:** No analytics SDKs, no third-party trackers; location data never leaves device.
- **Localization:** Support English and Traditional Chinese, using each operator's _en/_tc fields directly.
- **Attribution:** Verify and display required attribution per operator's terms (data.gov.hk for KMB/GMB; Citybus Limited's own copyright notice for CTB API data).

---

## 7. Testing Strategy

| Test Type | Coverage |
|---|---|
| Unit tests | Per-adapter parsing logic (KMB/CTB/GMB), travel-time estimator math, SQLite query correctness |
| Integration tests | Network layer against each operator's live/sandbox responses (mocked JSON fixtures per operator) |
| UI tests (XCUITest) | Map load -> stop tap -> ETA display flow (across operators); search -> route detail flow |
| Manual QA | Real-device testing during actual commutes across all three operators for ETA accuracy validation |

---

## 8. Deployment & Environments

- **Dev:** Local Xcode builds, simulator + personal device via free Apple ID (no paid enrollment needed for MapKit or local testing).
- **Beta:** TestFlight distribution once Apple Developer Program ($99/year) is enrolled, for friends/family testing.
- **Release:** Evaluate public App Store submission after v1.0 stability; otherwise remain a personal/TestFlight-only tool.

---

## 9. Open Technical Decisions

| Decision | Options | Recommendation |
|---|---|---|
| Persistence layer | GRDB vs Core Data | GRDB - better fit for raw SQL background and simpler schema migrations across 3 operators |
| Search indexing | LIKE vs FTS5 | Start with LIKE for MVP; migrate to FTS5 if search feels slow with combined 3-operator dataset |
| Cross-operator stop dedup | Show separately vs geographic clustering | v1: show separately (simpler, avoids false merges); v2: revisit with distance-threshold clustering if UX feedback warrants it |
| CTB ETA fetch pattern | Per-route calls vs caching aggressively | Cache known routes-per-stop from route-stop table; batch concurrent per-route ETA calls; respect 429 backoff |
| Travel-time accuracy | Uniform heuristic vs per-operator heuristic | Start uniform; refine per-operator (GMB routes are often shorter/faster between stops) once real trip data is logged |
| Map clustering | MapKit built-in vs custom | Use MapKit built-in clustering first; custom only if UX issues arise with 3-operator pin density |
