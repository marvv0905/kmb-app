# KMB ETA App — Development History

**App:** Ad-Free KMB Bus ETA for iOS  
**Author:** Rosario Justin  
**Version:** 0.1.0 (MVP — KMB only)  
**Last updated:** July 12, 2026  
**Min deployment:** iOS 17.6  
**Swift version:** 5.0  
**Understand-Anything code graph:** cd ~/.understand-anything-plugin/packages/dashboard && GRAPH_DIR="/Users/j__tin/Documents/GitHub/kmbAPP/kmb app" npx vite --host 127.0.0.1


---

## 1. Project Overview

A single-operator (KMB) bus ETA app for iOS with a **brutalist design system**. 3 tabs: Nearby stops with live ETAs, route search with custom keypad, and a settings panel. Route detail shows a MapKit map with road-following polylines and expandable stop ETAs.

### Comparison to original PRD/TRD (v0.3)

| Aspect | PRD/TRD Vision | Current Build |
|--------|---------------|---------------|
| Operators | KMB + CTB + GMB | KMB only |
| Architecture | MVVM + Adapter pattern (BusDataSource protocol) | MVVM — ViewModels call KMBAPIClient directly |
| Primary UI | Map view (map-centric) | List view with map on route detail only |
| Persistence | GRDB.swift (SPM) | Raw SQLite3 C API (no dependencies) |
| Search | Multi-operator, fuzzy, FTS5 | KMB-only, prefix-matching |
| Language | Swift 6 / iOS 17.0 | Swift 5.0 / iOS 17.6 |
| Tests | Unit (Swift Testing) + UI (XCUITest) | Stubs only |

---

## 2. Architecture

```
┌─────────────────────────────────────────────────┐
│  Views                                           │
│  HomeView   SearchView   SettingsView            │
│  RouteDetailView                                 │
├─────────────────────────────────────────────────┤
│  ViewModels (@Observable, @MainActor)            │
│  HomeVM     SearchVM     RouteDetailVM           │
├────────────────────┬────────────────────────────┤
│  Network (direct)  │  Persistence (SQLite3)      │
│  KMBAPIClient      │  AppDatabase                │
│  KMBDataTypes      │  StopRepo / RouteRepo       │
│  5 endpoints:      │  SyncMetaRepo               │
│  route, stop,      │  4 tables:                  │
│  route-stop,       │  routes, stops,             │
│  stop-eta,         │  route_stops, sync_meta     │
│  route-eta         │                             │
└────────────────────┴────────────────────────────┘
```

**Key design decisions:**
- **No external SPM dependencies** — raw SQLite3 via system `import SQLite3`
- **No adapter/protocol layer** — ViewModels call `KMBAPIClient` and decode `KMBDataTypes` directly. This is intentional KISS for an MVP. When adding CTB/GMB, introduce the adapter pattern per the TRD.
- **`@Observable` / `@MainActor`** — all ViewModels use iOS 17's Observation framework
- **Custom tab bar** — built in pure SwiftUI, not `UITabBar`, to avoid iOS glassmorphism issues

---

## 3. Features (implemented)

### Tab 1: Nearby (HomeView)

| Feature | How |
|---------|-----|
| Location permission | Custom prompt card → `CLLocationManager.requestWhenInUseAuthorization()` |
| Permission denied | Falls back to HK centre (22.3193, 114.1694) |
| Simulator detection | If reported location is >5km from HK, uses fallback |
| Nearby stops | Loads all 6750 KMB stops from SQLite, haversine-filtered ≤500m |
| Live ETAs | `GET /v1/transport/kmb/stop-eta/{stopId}` per stop, concurrent |
| ETA polling | Every 25s, `while !Task.isCancelled` |
| Pull-to-refresh | `.refreshable` triggers full stop reload |
| Data sync | Routes + stops + route-stops fetched on first launch, cached 24h |

### Tab 2: Search (SearchView)

| Feature | How |
|---------|-----|
| Custom keypad | Left: numeric grid (1-9, C/0/⌫). Right: letter grid (A/B through X) |
| Route fetch | `GET /v1/transport/kmb/route/` directly from API (not DB) |
| Search | Prefix-matching on `routeCode.uppercased()` |
| Results | Route code (red) + OUT/IN badge + origin → destination |
| Navigation | Tap result → push `RouteDetailView` |

### Tab 3: Settings (SettingsView)

| Feature | How |
|---------|-----|
| Language toggle | English / 繁體中文, persisted via `@AppStorage("app_language")` |
| Effect | All `LanguageHelper` methods switch text language |

### Route Detail (RouteDetailView)

| Feature | How |
|---------|-----|
| Map | MapKit `Map(position:)`, auto-zoom on stop selection |
| Road-following polyline | `MKDirections` (automobile) per consecutive stop pair via `withThrowingTaskGroup` |
| Stop markers | Custom `Annotation` views — sequence number in grey/red squares |
| Expandable list | Tap stop → fetch `GET /v1/transport/kmb/stop-eta/{stopId}`, up to 3 ETAs |
| Single-expand | Only one stop expanded at a time; toggling collapses previous |
| Bidirectional | Tap map marker → expands list. Tap list → zooms map to stop |
| ETA display | Minutes countdown, red if ≤3 min, "Due" if negative, remarks, absolute time |

---

## 4. Design System

### Colors

| Token | Value | Hex |
|-------|-------|-----|
| `bg` | Off-white | `#F2F2F2` |
| `accent` | KMB red | `#C8102E` |
| `text` | Pure black | `#000000` |
| `textSecondary` | Grey | `#666666` |
| `border` | Black | `#000000` |

### Typography

| Usage | Font | Weight |
|-------|------|--------|
| Route codes, ETAs, keypad, tab labels | Archivo Black (custom `.ttf`) | Regular |
| Chinese stop names, route destinations | System (PingFang fallback) | Heavy |

### Brutalist rules
- Corner radius: `0`
- Border width: `1.5px` (cards: `2px`)
- Shadow offset: `2px` (no blur)
- All backgrounds: opaque (`#F2F2F2`)
- No iOS glassmorphism — custom components replace `UITabBar`, `UINavigationBar` styled opaque

---

## 5. Data Layer

### Tables

```sql
CREATE TABLE routes (
    operator TEXT NOT NULL, 
  	route_code TEXT NOT NULL, 
  	bound TEXT NOT NULL,
    service_type TEXT, 
  	region TEXT,
    orig_en TEXT, 
  	orig_tc TEXT, 
  	orig_sc TEXT,
    dest_en TEXT, 
  	dest_tc TEXT, 
  	dest_sc TEXT,
    data_timestamp TEXT,
    PRIMARY KEY (operator, route_code, bound, service_type, region)
);

CREATE TABLE stops (
    operator TEXT NOT NULL, 
  	stop_id TEXT NOT NULL,
    name_en TEXT, 	
  	name_tc TEXT, 
  	name_sc TEXT,
    lat REAL NOT NULL, 
  	long REAL NOT NULL,
    region TEXT, 
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

CREATE TABLE sync_meta (
    key TEXT PRIMARY KEY, value TEXT
);
```

**No indexes** — the Simulator's iOS 26 SQLite has a reproducible WAL-mode btree corruption bug. Indexes were removed entirely. Queries on 6750-row tables use full scans (acceptable at this scale).

### Journal mode
- `DELETE` (not WAL) — avoids the Simulator corruption bug
- On each open, stale `-wal` and `-shm` files are deleted
- Transactions use `BEGIN IMMEDIATE` / `COMMIT` / `ROLLBACK`

### Sync strategy
- On first Home tab load: check `sync_meta` for 24h TTL
- If expired/absent: fetch routes + stops + route-stops from KMB API in sequence
- Upsert into SQLite tables (INSERT OR REPLACE)
- Set sync timestamp

---

## 6. API Integration

### Endpoints

| Endpoint | Used by | Response fields |
|----------|---------|----------------|
| `GET /v1/transport/kmb/route/` | Search, Home sync | `route`, `bound`, `service_type`, `orig_*`, `dest_*` |
| `GET /v1/transport/kmb/stop` | Home sync, Route detail | `stop`, `name_*`, `lat`, `long` (both strings) |
| `GET /v1/transport/kmb/route-stop/` | Home sync, Route detail | `route`, `bound`, `service_type`, `seq` (string), `stop` |
| `GET /v1/transport/kmb/stop-eta/{stopId}` | Home ETAs, Route detail ETAs | `route`, `dir`, `dest_*`, `eta_seq`, `eta` (ISO8601 or null), `rmk_*` |
| `GET /v1/transport/kmb/route-eta/{route}/{serviceType}` | (unused in current build) | `route`, `dir`, `service_type` (int), `seq` (int), `dest_*`, `eta_seq`, `eta`, `rmk_*` |

### KMB API quirks
- `lat`/`long` in stop endpoint are **strings** (not floats) — must `Double()` parse
- `seq` in route-stop is a **string** ("1"), but in route-eta is an **int** (1) — separate Codable structs needed
- `service_type` in route-eta is an **int**, but in route is a **string** — separate Codable structs needed
- Stop-eta response has NO `stop` field — must infer from request URL
- Stop-eta response has NO `service_type` or `seq` fields that match other endpoints

### Config
- Base URL: `https://data.etabus.gov.hk`
- Request timeout: 30s
- Resource timeout: 120s
- No authentication required

---

## 7. File Map

```
kmb app/
├── kmb_appApp.swift            # @main, theme init, ContentView, custom tab bar
├── Theme.swift                 # BrutalTheme tokens, fonts, BrutalDivider, modifiers
├── Color+App.swift             # Color.kmbRed extension
├── ArchivoBlack-Regular.ttf    # Custom brutalist font
├── Assets.xcassets/            # AppIcon (1024x1024), AccentColor
├── Models/
│   ├── BusOperator.swift       # Enum: kmb, ctb, gmb
│   ├── BusStop.swift           # Domain model + coordinate
│   ├── BusRoute.swift          # Domain model + displayLabel
│   └── ArrivalETA.swift        # Domain model + minutesAway, language-aware display
├── Network/
│   ├── KMBAPIClient.swift      # URLSession async HTTP client
│   └── KMBDataTypes.swift      # 5 KMB-specific Codable structs + KMBResponse wrapper
├── Persistence/
│   ├── AppDatabase.swift       # SQLite3 wrapper (open, read, write, migrate, integrity check)
│   ├── StopRepository.swift    # stops table CRUD
│   ├── RouteRepository.swift   # routes + route_stops table CRUD
│   └── SyncMetaRepository.swift # sync_meta key-value store
├── ViewModels/
│   ├── HomeViewModel.swift     # CLLocationManagerDelegate, 500m filter, ETA polling, sync
│   ├── SearchViewModel.swift   # Keypad layout, route prefix search, API fallback
│   └── RouteDetailViewModel.swift # MKDirections polyline, stop selection, per-stop ETA
├── Views/
│   ├── HomeView.swift          # Permission prompt, stop list, ETA labels
│   ├── SearchView.swift        # Keypad, input display, results list
│   ├── SettingsView.swift      # Language segmented control
│   ├── RouteDetailView.swift   # Map + stop list, BrutalStopMarker, BrutalStopRow
│   └── LanguageHelper.swift    # EN/TC text selector
└── service docs/
    ├── KMB_ETA_iOS_App_PRD_v0.3.md
    ├── KMB_ETA_iOS_App_TRD_v0.3.md
    ├── VERSION_HISTORY.md       # ← this file
    └── *.pdf                   # Operator API specs
```

---

## 8. Known Issues & Resolved Bugs

### Resolved

| Bug | Root cause | Fix |
|-----|-----------|-----|
| App crash on launch | `try! AppDatabase.shared` failed in Simulator sandbox | Moved DB init to async `RootView.setup()` with error handling |
| SQLite index corruption (1000+ console messages) | iOS 26 Simulator WAL-mode btree bug | Removed all indexes, switched to DELETE journal mode |
| SQL migration "table already exists" | `sqlite_master` stripped `IF NOT EXISTS` from stored SQL | Execute CREATE directly on real DB (not via temp DB replay) |
| "No routes found" on valid search | DB read returned empty `routeCode` fields (column mismatch) | Bypassed DB for search — fetch directly from KMB API |
| ETA spinner "forever" | `KMBETAData` decode failed — `service_type` was Int not String, `stop` field absent | Rebuilt `KMBETAData` to match actual API response |
| "No nearby stops" after granting location | Simulator returns Cupertino coordinates; 500m filter finds 0 KMB stops in California | Added >5km-from-HK detection → fallback |
| Route polyline "spider web" | `TaskGroup` returned segments in completion order, not route order | Each task returns `(index, coords)`, sorted before merging |
| Map markers not highlighting on select | `onTapGesture` inside `Annotation` intercepted by MapKit | Replaced with `Button` + `.buttonStyle(.plain)` |
| Tab bar glassmorphism | iOS 26 forces glass on `UITabBar` regardless of appearance settings | Replaced with custom SwiftUI `TabBar` component |
| Route detail map/stop gap | `GeometryReader` wrapped only the map, leaving unused height as whitespace | Wrapped entire VStack in GeometryReader |
| Backspace keypad button cut off | Keypad overlay behind custom tab bar | Changed from ZStack to VStack layout; tab bar pushes content |
| Deployment to older iOS failed | `MKMapItem(location:address:)` is iOS 26-only | Reverted to `MKMapItem(placemark: MKPlacemark(...))` |

### Open / Deferred

| Issue | Notes |
|-------|-------|
| No CTB/GMB operators | Requires adapter pattern + 2 new API clients |
| No map-primary view | PRD specifies map as primary UI |
| No pin clustering | Not needed at current KMB-only scale |
| No favorites/recents | Tables exist in schema but no UI or CRUD |
| No stop-name/landmark search | Route-number search only |
| No accessibility | Dynamic Type, VoiceOver not addressed |
| No real tests | All test files are Xcode template stubs |
| `debugRowCount` prints | Leftover debug code in `RouteRepository` |
| `print()` statements | Debug logging in `SearchViewModel` and `StaticDataSyncService` |
| Silent ETA fetch failures | Empty `catch {}` blocks swallow network errors |
| `BusOperator` enum has ctb/gmb cases | Unused — all code hardcodes `.kmb` |
| No rate limiting on ETA polling | 25s cycle fires N concurrent API calls (N = nearby stop count) |

---

## 9. Build Configuration

| Setting | Value |
|---------|-------|
| Product name | `kmb app` |
| Display name | `KMBeeee` |
| Bundle ID | `ram.kmb-app` |
| Marketing version | 1.0 |
| Build number | 1 |
| Team | `97X78M8PBJ` |
| Swift version | 5.0 |
| Project deployment target | iOS 17.6 |
| Target deployment target | iOS 18.6 |
| Devices | iPhone + iPad |
| Orientation | Portrait only |
| Info.plist generation | Auto (`GENERATE_INFOPLIST_FILE = YES`) |
| Custom fonts | `ArchivoBlack-Regular.ttf` |
| Location usage description | `"To stalk u of course (jk its to show nearby bus stops on the map lol)"` |
| Swift concurrency | `SWIFT_APPROACHABLE_CONCURRENCY = YES`, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` |

---

## 10. Future Roadmap

### v0.2 — CTB + GMB integration
1. Create `CTBAPIClient` + `GMBAPIClient` following TRD spec
2. Implement `BusDataSource` protocol
3. Create `KMBAdapter`, `CTBAdapter`, `GMBAdapter`
4. Add operator filter to Home tab (show KMB/CTB/GMB stops)
5. Respect CTB's HTTP 429 rate limiting with exponential backoff

### v0.3 — Map-primary + search enhancements
1. Redesign Home tab as Map view with stop pins
2. Tap pin → bottom sheet with routes + ETAs
3. Add stop-name/landmark search
4. Pin clustering for density

### v0.4 — Quality
1. Favorites / Recents CRUD
2. Dynamic Type + VoiceOver
3. Real unit tests (adapter parsing, haversine math, SQLite queries)
4. Remove debug `print()` statements
5. Better error UX (toasts/banners, not silent failures)
