# KMBeeee

Hong Kong bus ETA app offering real-time arrival times for KMB routes and stops, using the [KMB open data API](https://data.etabus.gov.hk).

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Language | Swift 5.0 |
| UI | SwiftUI |
| Architecture | MVVM |
| Database | SQLite3 (raw C API — no GRDB, no SPM deps) |
| Maps | MapKit + MKDirections |
| Networking | URLSession (async/await) |
| Minimum iOS | 18.6 (target), 17.6 (project) |

## Architecture

```
Views/          →  SwiftUI views (Home, Search, RouteDetail, Settings)
ViewModels/     →  @Observable + CLLocationManagerDelegate (HomeViewModel)
Network/        →  KMBAPIClient (5 endpoints), per-endpoint Codable structs
Persistence/    →  AppDatabase, RouteRepository, StopRepository, SyncMetaRepository
Models/         →  BusRoute, BusStop, ArrivalETA, BusOperator enum
```

- **No adapter layer** — ViewModels call `KMBAPIClient` directly
- **DB schema**: `routes`, `stops`, `route_stops`, `sync_meta` — all use `INSERT OR REPLACE`
- **DELETE journal mode** (not WAL) — iOS 26 Simulator has a known WAL btree corruption bug
- **No indexes** — removed due to the same iOS 26 Simulator bug

## Getting Started

```bash
git clone https://github.com/marvv0905/kmbAPP.git
cd "kmbAPP/kmb app"
xcodebuild -project "kmb app.xcodeproj" -scheme "kmb app" \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```

No `pod install`. No SPM resolve. Open `kmb app.xcodeproj` and hit Run.

> **First launch**: app opens its own SQLite file. If a corrupted DB is detected, it deletes and recreates automatically. To reset: delete `kmb_app.sqlite*` from the Simulator container.

## API

All data from the [KMB Data Portal](https://data.etabus.gov.hk) — no API key, no auth:

| Endpoint | Purpose |
|----------|---------|
| `/v1/transport/kmb/route` | All KMB routes |
| `/v1/transport/kmb/stop` | All KMB stops |
| `/v1/transport/kmb/route-stop` | Stops for a given route |
| `/v1/transport/kmb/stop-eta/{stopId}` | ETA for a stop |
| `/v1/transport/kmb/route-eta/{route}/{serviceType}` | ETA for a route |

## Design System

Defined in `Theme.swift`:

- **Colors**: `kmbRed` (#C8102E), `kmbBg` (#F2F2F2), `kmbDivider` (#1A1A1A)
- **Typography**: ArchivoBlack-Regular (bold headings), system font (body)
- **Custom tab bar** — avoids iOS 26 UITabBar glassmorphism entirely
- **Components**: BrutalStopMarker, BrutalStopRow, custom keypad (SearchView)

## Known Issues (In progress)

- **iOS 26 Simulator WAL index corruption** — if you see `index corruption at line 109433`, delete all `kmb_app.sqlite*` files from Simulator containers. App auto-recovers on next launch.
- **Simulator location fallback** — Simulator returns Cupertino coordinates. Code auto-detects this (>5km from HK) and falls back to HK centre `(22.3193, 114.1694)`.
- **CTB/GMB not yet implemented** — `BusOperator` enum has `.ctb` and `.gmb` cases, but only KMB endpoints are wired up.

## Documentation

- `AGENTS.md` — LLM context (build commands, DB rules, API quirks, architecture notes)
- `kmb app/service docs/` — PRD, TRD, API specifications (KMB, CTB, GMB), version history

## License

MIT
