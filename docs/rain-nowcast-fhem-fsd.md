# rain-nowcast-fhem Functional Specification Document

## 1. System Overview

### Purpose

Provide a local FHEM solution based on `HTTPMOD` and `myUtils` that evaluates
Rainbow.ai nowcast data for one configured location and exposes actionable
short-term rain states through FHEM readings.

### Goals

- Turn high-resolution nowcast data into automation-friendly states.
- Support explainable and robust weather-driven decisions in FHEM.
- Make the first version useful for concrete scenarios such as roof-window
  warnings, awning control, and watering suppression.
- Keep the implementation inside standard FHEM building blocks without
  introducing a dedicated custom device module.

### Out of scope

- Multiple locations in v1
- Historical analysis in v1
- A separate graphical UI in v1
- Cloud-hosted decision logic in v1 `(assumed)`
- Custom FHEMWEB rendering or custom web UI hooks in v1

## 2. System Architecture

### Components

| Component | Responsibility | Notes |
|---|---|---|
| Rainbow.ai API client | Fetch nowcast data for one configured location | Requires API key and network access |
| Forecast evaluator | Derive actionable rain states from raw forecast data | Applies thresholds and timing logic |
| HTTPMOD device integration | Fetch data and expose readings on one FHEM device | Implemented with `HTTPMOD`, `userReadings`, and `myUtils` |
| Configuration layer | Hold API key, location, and polling settings | Initial configuration scope to be kept small |
| Diagnostics layer | Provide explainable state transitions and API status | Supports daily-use troubleshooting |

### Data and control flow

1. FHEM triggers a periodic update.
2. The system requests nowcast data from Rainbow.ai for the configured
   location.
3. Raw forecast data is evaluated against thresholds and timing logic.
4. Derived states are written as FHEM readings on the project device.
5. Other FHEM automations can react to those readings.

### Preferred implementation shape

The implementation shall stay inside one existing `HTTPMOD` device plus
supporting `userReadings` and `myUtils` helper functions.

Proposed file layout:

- `docs/rain-nowcast-fhem-httpmod-prototype.md`
- `docs/rain-nowcast-fhem-httpmod-myutils-prototype.md`
- `scripts/99_myUtils_RainNowcastProto.pm.example`

The preferred runtime shape is:

- one `HTTPMOD` device for the Rainbow.ai request
- a hidden `.raw_json` reading that stores the current response payload
- compact derived readings on the same device via `userReadings`
- parsing and evaluator logic in `myUtils`

This architecture is now the selected v1 solution, not a temporary prototype.

## 3. Phases

| Phase | Scope | Exit criteria |
|---|---|---|
| Phase 1 | Specification and scaffolding | Idea, FSD, phase plan, and verification approach are documented and consistent. |
| Phase 2 | HTTPMOD + myUtils core behavior | One configured location can be polled and relevant rain readings are exposed on one HTTPMOD-based FHEM device. |
| Phase 3 | Robustness and polish | Threshold tuning, diagnostics, and failure handling are good enough for daily use. |

## 4. Requirements

### Functional Requirements

| ID | Priority | Requirement |
|---|---|---|
| FR-1.1 | Must | The system shall authenticate against the Rainbow.ai API using a configured API key. |
| FR-1.2 | Must | The system shall retrieve short-term nowcast data for one configured location. |
| FR-1.3 | Must | The system shall derive a "rain in X minutes" state from the retrieved forecast data. |
| FR-1.4 | Must | The system shall derive a rain-intensity state from the retrieved forecast data. |
| FR-1.5 | Must | The system shall derive a dry or rain window state suitable for automation decisions. |
| FR-1.6 | Must | The system shall expose the derived states as readings on the project FHEM device. |
| FR-1.7 | Should | The system shall make the decision logic configurable through thresholds and polling settings. |
| FR-1.8 | Should | The system shall expose enough diagnostic information to understand why a state changed. |
| FR-1.9 | Should | The system shall expose API health and forecast freshness as FHEM-readable diagnostics. |
| FR-1.10 | Must | The system shall be implemented with one `HTTPMOD`-based FHEM device plus `userReadings` and `myUtils` helper functions. |
| FR-1.11 | Must | The system shall access the Rainbow.ai Nowcast API through documented HTTP requests from `HTTPMOD` and parse the documented response fields `forecast`, `summary.intensity`, `precipRate`, `precipType`, `timestampBegin`, and `timestampEnd`. |
| FR-1.12 | Must | The system shall keep the Rainbow.ai request, compact helper readings, and state exposure on a single HTTPMOD-based FHEM device. |
| FR-1.13 | Must | The system shall store the current raw response payload in a hidden reading such as `.raw_json` and derive rain helper readings from that payload. |

### Non-Functional Requirements

| ID | Priority | Requirement |
|---|---|---|
| NFR-1.1 | Must | The system shall keep all automation logic local to the FHEM environment except for the external API request. |
| NFR-1.2 | Must | The system shall support traceability between requirements and verification cases. |
| NFR-1.3 | Should | The system shall be structured so additional automation rules can be added without major refactoring. |
| NFR-1.4 | Should | The system shall behave robustly enough that noisy forecast fluctuations do not cause impractical automation behavior. |
| NFR-1.5 | Must | The implementation shall not require a project-specific custom FHEM device module in v1. |
| NFR-1.6 | Must | The implementation shall keep the visible reading set compact and shall avoid exposing hundreds of flattened forecast storage readings in normal operation. |
| NFR-1.7 | Should | The implementation shall derive helper readings from one current payload source instead of scanning stale leftover indexed readings across updates. |
| NFR-1.8 | Should | The implementation shall keep hidden helper data in dotted readings such as `.raw_json` where this improves maintainability and reduces visual clutter. |
| NFR-1.9 | Should | The implementation shall follow FHEM state-handling guidance by deriving the visible device status from readings or `stateFormat` instead of setting internal `STATE` directly. |

## 5. Risks, Assumptions, and Dependencies

| Type | Item | Mitigation |
|---|---|---|
| Assumption | Rainbow.ai provides the required short-term forecast resolution and stable API access. | Validate API contract before implementation. |
| Assumption | FHEM can represent the target states cleanly through one HTTPMOD-based device with readings. | Confirm preferred FHEM integration approach in Phase 2. |
| Assumption | The documented Rainbow.ai nowcast access pattern is simple enough to run reliably through `HTTPMOD`. | Validate with one minimal FHEM configuration and keep the working shape stable. |
| Risk | Forecast noise causes unstable state flapping. | Define hysteresis, thresholds, and polling rules before implementation. |
| Risk | API outages or malformed responses reduce automation reliability. | Add error readings and safe fallback behavior. |
| Risk | Raw response storage may accidentally include header fragments or multiple JSON-looking sections. | Extract the final decodable JSON document defensively from `.raw_json`. |
| Risk | Flattened forecast readings from older HTTPMOD updates may remain when a newer response has fewer entries. | Derive helper readings only from the current `.raw_json` payload, not from indexed storage readings. |
| Risk | Event load or visual clutter may grow if helper storage readings become visible. | Keep raw payload data in dotted hidden readings and keep visible readings compact. |
| Dependency | Network access to Rainbow.ai API is available from the FHEM host. | Verify connectivity early. |
| Dependency | API key provisioning and secure storage are available. | Define configuration handling in implementation phase. |

## 6. Interfaces and Data Models

### Hardware Interfaces

| Interface | Pins/Port | Direction | Notes |
|---|---|---|---|
| None in v1 | n/a | n/a | The first version is software-focused inside FHEM. |

### Software Interfaces

| Interface | Endpoint/Topic/Command | Payload | Expected response |
|---|---|---|---|
| Rainbow.ai Nowcast API | `GET /nowcast/v1/precip-global/{longitude}/{latitude}` `(preferred)` | Path params `longitude`, `latitude`; optional `start_timestamp`; auth via `Ocp-Apim-Subscription-Key` header | JSON with `forecast[]`, `summary.intensity`, `latitude`, `longitude` |
| Rainbow.ai Nowcast API | `GET /nowcast/v1/precip/{longitude}/{latitude}` `(fallback/alternative)` | Same as above | JSON with same schema; may return `404` where data is unavailable |
| FHEM HTTPMOD device | `define <name> HTTPMOD <URL> <Interval>` plus headers, JSON parsing, regex extraction, and formatting attributes | Rainbow.ai request URL and headers | Compact summary readings, hidden raw payload reading, and derived helper readings on one device |

### API behavior and error handling

The implementation shall treat the following Rainbow.ai API behavior as part of the
contract:

- authentication by header `Ocp-Apim-Subscription-Key` is preferred
- the documented nowcast endpoints are `GET` requests, not `POST`
- missing or invalid token may result in `401 Unauthorized`
- invalid requests may return `400`
- unsupported or unavailable location coverage may return `404`
- validation problems may return `422`

The implementation shall treat `forecast` as the minute-level primary data source and
`summary.intensity` as a summary helper, not as the only decision input.

Observed prototype evidence on 2026-05-02:

- `HTTPMOD` exposed `summary_intensity` directly
- `forecast[]` array entries were flattened into indexed readings such as
  `forecast_01_precipRate`, `forecast_01_precipType`,
  `forecast_01_timestampBegin`, and `forecast_01_timestampEnd`
- later indexed readings such as `forecast_100_precipType = rain` and
  `forecast_100_precipRate > 0` confirm that the payload is usable for
  deriving "rain in X minutes" logic in FHEM
- variant B confirmed that named readings such as `summary_intensity`,
  `latitude`, and `longitude` work, while `extractAllJSON 1` keeps the full raw
  forecast expansion available for debugging and derivation
- variant B also showed that stale higher-index `forecast_<nn>_*` readings may
  remain from older updates, so derivation logic must guard against leftover
  data
- variant B without `extractAllJSON` confirmed that a compact HTTPMOD device is
  easy to maintain visually, but it no longer exposes forecast-slot raw
  readings in `READINGS`
- storing the response in `.raw_json` and parsing it in `myUtils` produced
  consistent live helper readings such as `rain_now = 1`,
  `rain_in_minutes = 0`, `next_rain_begin` aligned to the current minute, and
  `fresh_slot_count = 238`

The implementation shall rely on `HTTPMOD` for polling and HTTP request
execution. Direct custom use of lower-level FHEM HTTP helper APIs is not part
of the planned v1 architecture.

### Proposed reading set for v1

| Reading | Meaning |
|---|---|
| `state` | High-level current status of the device |
| `summary_intensity` | Direct Rainbow.ai summary intensity |
| `latitude` | Configured/requested latitude returned by the API |
| `longitude` | Configured/requested longitude returned by the API |
| `rain_in_minutes` | Estimated lead time until rain reaches the configured location |
| `next_rain_rate` | Precipitation rate of the first relevant rain slot |
| `next_rain_type` | Precipitation type of the first relevant rain slot |
| `next_rain_begin` | Local timestamp of the first relevant rain slot |
| `rain_now` | Boolean-style current rain indicator |
| `rain_state` | Compact derived state such as `dry`, `rain_now`, `rain_soon`, or `later_rain` |
| `fresh_slot_count` | Count of forecast entries in the current payload |
| `.raw_json` | Hidden raw payload used by `myUtils` parsing |

Confirmed additional prototype behavior:

- `stateFormat` can already map cleanly to `summary_intensity`
- the current device can expose a compact top-level state and compact helper
  readings on one device
- disabling `extractAllJSON` collapses the visible readings to the explicitly
  named summary/location readings
- a hidden `.raw_json` reading can store the response payload while keeping the
  device visually clean
- `myUtils` can derive rain helper readings directly from `.raw_json` without
  scanning hundreds of flattened storage readings

Prototype architecture implication:

- `HTTPMOD` can serve as both request device and final presentation device
- detailed rain-slot derivation is handled cleanly by `myUtils` against one
  hidden payload reading
- the selected architecture for v1 is one same-device solution based on
  `HTTPMOD`, `userReadings`, `.raw_json`, and `myUtils`

Reading design notes from FHEM documentation:

- `state` remains the main human-readable top-level state
- `availability` is preferred for generic online/offline presence
- related reading updates should be grouped to avoid unnecessary event load
- hidden helper readings may use a leading dot if small persistent internal
  values are needed
- reading values should remain machine-usable and should not embed units unless
  there is a strong FHEM convention for that reading

### HTTPMOD attributes and helper structure for v1

Expected core configuration elements:

- `define <name> HTTPMOD <URL> <Interval>`
- request headers including `Ocp-Apim-Subscription-Key`
- named JSON readings for `summary_intensity`, `latitude`, and `longitude`
- one hidden regex-based reading such as `.raw_json`
- `userReadings` for `rain_now`, `rain_in_minutes`, `next_rain_rate`,
  `next_rain_type`, `next_rain_begin`, `rain_state`, and `fresh_slot_count`
- `stateFormat` derived from `rain_state`

## 7. Operational Procedures

### Build

```powershell
No standalone build step in v1
```

### Flash or deploy

```powershell
Copy the tested helper functions into `99_myUtils.pm`, reload `myUtils`, and
apply the HTTPMOD attributes in FHEM
```

### Monitor

```powershell
Observe FHEM device readings and implementation logs
```

### Recovery

If API requests fail, the system should preserve or clearly invalidate the last
known state and expose an error indicator. Exact fallback semantics remain open.

Suggested initial behavior:

- keep last successful forecast-derived readings
- update a diagnostic reading or state helper if configured
- expose forecast staleness via reading timestamps or payload age helper logic

## 8. Verification and Validation

| Test ID | Covers | Preconditions | Steps | Expected result |
|---|---|---|---|---|
| TC-1.1 | FR-1.1, FR-1.2 | Valid API key and configured location | Request a forecast update. | Forecast data is retrieved successfully for the configured location. |
| TC-1.2 | FR-1.3 | Retrieved forecast data includes imminent rain | Evaluate the forecast. | The "rain in X minutes" reading reflects the expected lead time. |
| TC-1.3 | FR-1.4 | Retrieved forecast data includes measurable precipitation | Evaluate the forecast. | The rain-intensity reading reflects the expected intensity band or value. |
| TC-1.4 | FR-1.5 | Forecast data spans rain and dry periods | Evaluate the forecast. | The rain or dry window reading is derived consistently. |
| TC-1.5 | FR-1.6 | FHEM integration is active | Trigger an update cycle. | Derived states are written to the same HTTPMOD-based FHEM device readings. |
| TC-1.6 | FR-1.7, NFR-1.4 | Configurable thresholds and polling are available | Adjust thresholds and rerun evaluation. | Behavior changes predictably without noisy oscillation. |
| TC-1.7 | FR-1.8 | Diagnostics are enabled | Trigger at least one state transition. | The system exposes enough information to explain the transition. |
| TC-1.8 | FR-1.9 | API failure or stale data can be simulated | Force a failed or stale update. | FHEM diagnostics expose API status and forecast freshness. |
| TC-1.9 | FR-1.10, NFR-1.5 | Repository structure is current | Review implementation files and paths. | The architecture uses one HTTPMOD device plus `myUtils` and does not require a custom FHEM device module. |
| TC-1.10 | FR-1.11 | Valid API key and test location are available | Trigger a live or mocked Rainbow.ai request. | HTTPMOD parses documented endpoint fields and updates derived helper state correctly. |
| TC-1.11 | NFR-1.6, NFR-1.8 | Compact device configuration is active | Review visible readings after an update. | The visible reading set remains compact and helper payload storage is hidden in a dotted reading. |
| TC-1.12 | NFR-1.1, NFR-1.2, NFR-1.3, NFR-1.7, NFR-1.9 | Repository docs are current | Review implementation and documentation. | Logic remains local, traceable, maintainable, payload-based, and FHEM-compatible. |
| TC-1.13 | FR-1.12 | HTTPMOD is available in FHEM | Configure one HTTPMOD device against Rainbow.ai. | One same-device setup can fetch nowcast JSON and expose both summary and helper readings. |
| TC-1.14 | FR-1.3, FR-1.4, FR-1.11, FR-1.13 | Live payload data is available | Review `.raw_json` and the resulting helper readings in FHEM. | The current payload is sufficient to derive timing and intensity helper states. |
| TC-1.15 | NFR-1.4, NFR-1.7 | Multiple updates with varying forecast lengths are available | Compare old indexed storage readings with payload-derived helper readings. | Helper logic based on `.raw_json` remains correct even when old indexed storage readings would be stale. |
| TC-1.16 | FR-1.12, FR-1.13 | Compact HTTPMOD setup with hidden payload is available | Review visible readings and hidden payload behavior. | The device remains visually clean while `.raw_json` preserves the current response for evaluation. |
| TC-1.17 | FR-1.12, FR-1.13 | HTTPMOD device and `userReadings`/`myUtils` are available | Trigger a live update during active rain or imminent rain. | The same HTTPMOD device exposes correct helper readings such as `rain_now`, `rain_in_minutes`, and `fresh_slot_count`. |

## 9. Troubleshooting and Diagnostics

| Symptom | Likely cause | Diagnostic step | Fix |
|---|---|---|---|
| No readings update | API request failed or scheduler did not run | Check logs, connectivity, and last update timestamp | Restore connectivity or fix scheduling |
| Rain state looks wrong | Thresholds or forecast interpretation are off | Compare raw forecast data to derived readings | Tune thresholds or adjust evaluator logic |
| States flap too often | Polling or thresholds are too sensitive | Review change frequency and raw values | Add hysteresis or widen thresholds |

## 10. Appendix

### Traceability Matrix

| Requirement | Tests | Status |
|---|---|---|
| FR-1.1 | TC-1.1 | Covered |
| FR-1.2 | TC-1.1 | Covered |
| FR-1.3 | TC-1.2 | Covered |
| FR-1.4 | TC-1.3 | Covered |
| FR-1.5 | TC-1.4 | Covered |
| FR-1.6 | TC-1.5 | Covered |
| FR-1.7 | TC-1.6 | Covered |
| FR-1.8 | TC-1.7 | Covered |
| FR-1.9 | TC-1.8 | Covered |
| FR-1.10 | TC-1.9 | Covered |
| FR-1.11 | TC-1.10 | Covered |
| FR-1.12 | TC-1.13, TC-1.16, TC-1.17 | Covered |
| FR-1.13 | TC-1.14, TC-1.16, TC-1.17 | Covered |
| FR-1.3 | TC-1.14 | Covered by payload-based prototype evidence |
| FR-1.4 | TC-1.14 | Covered by payload-based prototype evidence |
| NFR-1.1 | TC-1.12 | Covered |
| NFR-1.2 | TC-1.12 | Covered |
| NFR-1.3 | TC-1.12 | Covered |
| NFR-1.4 | TC-1.6 | Covered |
| NFR-1.4 | TC-1.15 | Covered by prototype edge-case planning |
| NFR-1.5 | TC-1.9 | Covered |
| NFR-1.6 | TC-1.11 | Covered |
| NFR-1.7 | TC-1.12, TC-1.15 | Covered |
| NFR-1.8 | TC-1.11 | Covered |
| NFR-1.9 | TC-1.12 | Covered |

### Implementation references

Primary implementation references for v1:

- Rainbow.ai API docs: `https://doc.rainbow.ai`
- Rainbow.ai Nowcast API reference: `https://doc.rainbow.ai/api-ref/nowcast/`
- FHEM HTTPMOD wiki and command reference
- FHEM documentation for `userReadings`
- FHEM state and reading handling guidance as used by standard devices
