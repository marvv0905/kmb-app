<!-- headroom:rtk-instructions -->
# RTK (Rust Token Killer) - Token-Optimized Commands

When running shell commands, **always prefix with `rtk`**. This reduces context
usage by 60-90% with zero behavior change. If rtk has no filter for a command,
it passes through unchanged — so it is always safe to use.

## Key Commands
```bash
# Git (59-80% savings)
rtk git status          rtk git diff            rtk git log

# Files & Search (60-75% savings)
rtk ls <path>           rtk read <file>         rtk grep <pattern>
rtk find <pattern>      rtk diff <file>

# Test (90-99% savings) — shows failures only
rtk pytest tests/       rtk cargo test          rtk test <cmd>

# Build & Lint (80-90% savings) — shows errors only
rtk tsc                 rtk lint                rtk cargo build
rtk prettier --check    rtk mypy                rtk ruff check

# Analysis (70-90% savings)
rtk err <cmd>           rtk log <file>          rtk json <file>
rtk summary <cmd>       rtk deps                rtk env

# GitHub (26-87% savings)
rtk gh pr view <n>      rtk gh run list         rtk gh issue list

# Infrastructure (85% savings)
rtk docker ps           rtk kubectl get         rtk docker logs <c>

# Package managers (70-90% savings)
rtk pip list            rtk pnpm install        rtk npm run <script>
```

## Rules
- In command chains, prefix each segment: `rtk git add . && rtk git commit -m "msg"`
- For debugging, use raw command without rtk prefix
- `rtk proxy <cmd>` runs command without filtering but tracks usage
<!-- /headroom:rtk-instructions -->

## Project Context

### Build
```bash
xcodebuild -project "kmb app.xcodeproj" -scheme "kmb app" \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```
- **No SPM dependencies** — raw SQLite3 (`import SQLite3`), no GRDB
- **Min deployment**: iOS 17.6 (project), 18.6 (target)
- **Swift 5.0** with `SWIFT_APPROACHABLE_CONCURRENCY` and `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`
- **Custom font**: `ArchivoBlack-Regular.ttf` bundled in `kmb app/`, registered in Info.plist via `INFOPLIST_KEY_UIAppFonts`

### SQLite — Critical Rules
- **NO indexes.** iOS 26 Simulator has a WAL-mode btree corruption bug (`index corruption at line 109433`). All indexes were removed.
- **DELETE journal mode** (not WAL). If you see index corruption errors, delete `kmb_app.sqlite*` from ALL Simulator containers:
  ```bash
  find ~/Library/Developer/CoreSimulator -name "kmb_app.sqlite*" -delete
  ```
- Database auto-recovers: on open, runs `PRAGMA integrity_check`. If corrupt, deletes + recreates.
- 4 tables: `routes`, `stops`, `route_stops`, `sync_meta`. All use `INSERT OR REPLACE`.

### KMB API Quirks
- **stop-eta endpoint**: response has NO `stop` field — use the stopId from the request URL. `service_type` is Int (not String). `seq` is Int (not String).
- **route-stop endpoint**: `seq` is String ("1"), not Int.
- **route-eta endpoint**: `service_type` is Int, `seq` is Int.
- **route endpoint**: `service_type` is String. No `co` field.
- These inconsistencies forced separate Codable structs per endpoint: `KMBRouteData`, `KMBStopData`, `KMBRouteStopData`, `KMBETAData`, `KMBRouteETAData`.

### SearchViewModel — Do NOT Re-add DB Reads
- `SearchViewModel.loadRoutesFromDB()` fetches routes directly from the KMB API — **not from SQLite**.
- This is intentional. A previous implementation read from DB but returned empty columns (root cause was never fully identified, likely a column-index mismatch in the raw SQLite3 row-to-struct mapping).
- The DB is only used by `HomeViewModel` for sync + spatial filtering.

### Location
- `HomeViewModel` is both `@Observable` and `CLLocationManagerDelegate`.
- Falls back to HK centre `(22.3193, 114.1694)` when location is unavailable.
- Simulator returns Cupertino coordinates — code auto-detects this (>5km from HK → uses fallback).
- Permission card appears if `authorizationStatus` is `.notDetermined` or `.denied`.

### Architecture
- **MVVM, no adapter layer.** ViewModels call `KMBAPIClient` directly.
- When adding CTB/GMB: implement the `BusDataSource` protocol from the TRD (`service docs/KMB_ETA_iOS_App_TRD_v0.3.md`), create adapter classes, then wire into ViewModels.
- `BusOperator` enum already has `ctb` and `gmb` cases (unused).
- **Brutalist design system** in `Theme.swift` — off-white `#F2F2F2`, KMB red `#C8102E`, zero-radius, custom tab bar (not UITabBar — iOS 26 glassmorphism forced the switch).

### Knowledge Graph
- Built via `/understand`, stored at `.ua/knowledge-graph.json` (38 nodes, 39 edges, 9 layers)
- Dashboard: `cd ~/.understand-anything-plugin/packages/dashboard && GRAPH_DIR="<project>" npx vite --host 127.0.0.1`

### Build output
- Product: `kmb app.app`
- Bundle ID: `ram.kmb-app`
- Display name: `KMBeeee`
