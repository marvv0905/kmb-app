# Product Requirements Document (PRD)
## Ad-Free Multi-Operator Bus ETA App for iOS

**Author:** Rosario Justin
**Version:** 0.3 (Draft)
**Date:** July 11, 2026
**Status:** Draft for review
**Changelog from v0.2:** Corrected travel-time feature scope to in-vehicle bus ride duration between two stops on a route (not a full walk+wait+ride+walk journey planner to an arbitrary destination).

---

## 1. Overview

### 1.1 Problem Statement
The official KMB mobile app displays significant advertisements that degrade the user experience when checking bus arrival times. This product is a native iOS application that provides real-time bus/minibus ETA information across multiple Hong Kong operators, with zero ads and a clean, fast, map-centric interface.

### 1.2 Goals
- Deliver an ad-free, fast, and reliable way to check bus/minibus arrivals across KMB, CTB, and GMB.
- Provide a native map experience for discovering nearby stops and routes regardless of operator.
- Offer unified search across all three operators' routes, stops, and destinations.
- Estimate in-vehicle bus travel time between a boarding and alighting stop on a chosen route, across all available operators.
- Serve as a portfolio-quality iOS/data engineering project demonstrating multi-source API integration, mapping, and clean architecture.

### 1.3 Non-Goals (v1)
- No support for NLB, MTR, or light rail in v1 (may be considered post-MVP).
- No ticketing, payment, or Octopus card integration.
- No Android version in v1.
- No user accounts / server-side backend beyond a lightweight caching layer (v1 is largely client-driven).
- No automatic cross-operator stop de-duplication in v1 (see Section 8 Open Questions) - stops from each operator are shown as distinct pins even if physically co-located.

---

## 2. Target User

- **Primary:** Daily commuters in Hong Kong who use a mix of KMB buses, CTB buses, and green minibuses and want one ad-free app instead of three separate ones.
- **Secondary:** The developer (self) - used as a personal daily-driver app and as a technical portfolio piece for data analytics / BI / software engineering internship applications.

---

## 3. Data Sources

All data is sourced from official, free, key-free government/operator open APIs. No authentication is required for any of the three.

| Operator | Base URL | Stop ID Format | Notes |
|---|---|---|---|
| KMB + LWB | https://data.etabus.gov.hk/ | 16-char hex string | LWB routes are bundled under co: KMB |
| CTB (Citybus) | https://rt.data.gov.hk/v2/transport/citybus/ | 6-digit zero-padded number | Also covers former New World First Bus routes under companyid: CTB |
| GMB (Green Minibus) | https://data.etagmb.gov.hk/ | Integer Stop ID | Routes are scoped by region (HKI/KLN/NT) and route codes are NOT unique across regions |

Each operator exposes broadly equivalent endpoint types (Route List, Stop List, Route-Stop List, Stop/Route ETA), but with different schemas, identifiers, and parameter shapes - this is addressed in the TRD's normalization layer.

---

## 4. Feature Requirements

### 4.1 Map View (P0)
- Interactive native Apple Map (MapKit, SwiftUI Map view) showing nearby stops from all three operators as pins, centered on user location.
- Visual distinction (color/icon) per operator so users can tell KMB, CTB, and GMB stops apart at a glance.
- Tapping a stop pin opens a bottom sheet listing all routes and live ETAs at that stop, regardless of operator.
- Clustering of stop pins at low zoom levels for performance.
- User location shown as a live-updating blue dot with heading (via CoreLocation).

### 4.2 ETA Display (P0)
- Real-time countdown (minutes) for each upcoming bus/minibus at a selected stop, refreshed automatically per operator's live ETA endpoint.
- Show remarks (e.g. "Scheduled Bus," service unavailable reasons) surfaced from each operator's remark fields.
- Visual distinction for imminent arrivals (e.g. under 3 minutes).
- GMB stops surface both relative (diff, in minutes) and absolute ETA - display using the relative value for consistency with KMB/CTB's countdown style.

### 4.3 Search (P0)
- Search by route number/code across all three operators (clearly labeled by operator, since route codes may collide, e.g. GMB route codes are only unique within a region).
- Search by stop name or nearby address/landmark, merged across operators.
- Autocomplete/fuzzy matching using cached static route/stop data.

### 4.4 Estimated In-Vehicle Bus Travel Time (P1)
- For a selected route, user picks a boarding stop and an alighting stop (in correct sequence order).
- App estimates how long the bus ride itself will take between those two stops, derived primarily from the operator's live ETA data at both stops (difference between matched upcoming-trip ETAs), falling back to a stop-sequence heuristic (hop count x average inter-stop time) when live data is unavailable.
- Displayed alongside the live "next bus" countdown, e.g. "Next bus in 4 min, ~14 min ride to your stop."
- Out of scope for v1: full walk+wait+ride+walk journey planning to an arbitrary destination address (see v2 roadmap).

### 4.5 Favorites / Recents (P1)
- Save frequently used stops/routes (tagged by operator) for one-tap access.
- Recent searches list.

### 4.6 Notifications (P2 / Stretch)
- Optional local notification when a saved route's bus is a set number of minutes away from a chosen stop.
- Foreground-only in v1; background geofence-based alerts considered for v2.

---

## 5. Technical Architecture (Summary - see TRD for full detail)

- **Language/Framework:** Swift, SwiftUI, native MapKit - "import MapKit" plus a "Map" view is sufficient to render the map; no API key, no Maps capability toggle, and no Apple Developer Program enrollment are required for this core functionality. The "Maps" capability in Xcode is only needed if the app registers as a system-wide routing provider, which is out of scope.
- **Location permission:** NSLocationWhenInUseUsageDescription in Info.plist is required only once CLLocationManager is used to show the live user-location dot.
- **Multi-operator abstraction:** A BusOperator protocol with three adapters (KMB, CTB, GMB) normalizing each operator's schema into shared domain models (BusStop, BusRoute, ArrivalETA).
- **Persistence:** SQLite (via GRDB) caching static route/stop/fare data per operator, refreshed daily.

---

## 6. Non-Functional Requirements

- **Performance:** Map should render smoothly with 60fps scrolling even with hundreds of stop pins from three operators visible (via clustering).
- **Reliability:** Must gracefully degrade per-operator (e.g. if CTB returns HTTP 429 rate-limit responses, KMB and GMB data should still display normally).
- **Privacy:** Location data used only on-device for map centering; no user data sent to third-party servers.
- **Ad-free:** No advertisements or tracking SDKs across any operator's data display.
- **Accessibility:** Support Dynamic Type and VoiceOver for stop/ETA lists.
- **Attribution:** Confirm and comply with each operator's data usage/attribution terms (KMB/GMB via data.gov.hk terms; CTB has its own copyright notice on its API documentation).

---

## 7. Success Metrics (Personal Project)

- App is used as primary daily commute tool across all three operators, replacing the official apps.
- Core flows (map load -> stop tap -> ETA display) complete in under 2 seconds on typical Hong Kong LTE/5G, per operator.
- Portfolio value: demonstrable, polished case study for internship applications (multi-source data pipeline + native iOS + UX).

---

## 8. Risks & Open Questions

| Risk / Question | Mitigation / Status |
|---|---|
| Apple Developer Program cost ($99/year) for App Store distribution | Not required for MapKit itself; only needed for App Store submission. Sideload via Xcode for personal use. |
| Three different API schemas increase integration complexity | Addressed via normalization/adapter layer in TRD Section 3-4. |
| CTB explicitly rate-limits (HTTP 429); KMB/GMB do not document limits | Implement conservative polling intervals and per-operator backoff. |
| Same physical stop served by multiple operators has no shared cross-reference ID | v1: show as separate pins per operator. v2 (open question): consider geographic clustering/dedup with a distance threshold. |
| GMB route codes are not unique across regions | Always store/display GMB routes with their region tag to avoid ambiguity. |
| In-vehicle travel time estimation accuracy when live ETA data is sparse (e.g. late-night GMB routes) | Fall back to stop-sequence heuristic (hop count x average inter-stop time); refine later with logged historical data. |

---

## 9. Roadmap / Phasing

- **v0.1 (MVP):** Map view (KMB + CTB + GMB pins), stop tap -> live ETA per operator, basic multi-operator route/stop search.
- **v0.2:** Estimated in-vehicle bus travel time between stops on a route, favorites/recents.
- **v0.3:** Foreground arrival notifications, UI polish, accessibility pass.
- **v1.0:** TestFlight release for personal/friends use; evaluate App Store submission.
- **v2 (stretch):** Background stop-approach alerts, cross-operator stop de-duplication, NLB/MTR/light rail support, Android/web companion.
