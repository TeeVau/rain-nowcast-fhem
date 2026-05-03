# rain-nowcast-fhem Implementation Phase Plan

## Current phase

Phase: Phase 2

Goal: Prove the Rainbow.ai request/response flow and first useful readings with
the selected `HTTPMOD + myUtils` architecture on one compact FHEM device.

## Phase 1: Foundation

### Scope

- Capture the project idea and constraints.
- Define core requirements and verification cases.
- Keep the implementation form open until the FHEM integration approach is
  clearer.

### Likely files/modules

- `docs/rain-nowcast-fhem-idea.md`
- `docs/rain-nowcast-fhem-fsd.md`
- `docs/rain-nowcast-fhem-phase-plan.md`
- `docs/rain-nowcast-fhem-verification-log.md`

### Build command

```powershell
No build in Phase 1
```

### Verification

- Review idea, FSD, and traceability for consistency.
- Confirm that every Must and Should requirement has at least one test case.

### Exit criteria

- Inputs, outputs, and v1 boundaries are documented.
- Core FR/NFR set exists.
- Verification cases exist for all Must and Should requirements.

## Phase 2: HTTPMOD + myUtils core behavior

### Scope

- Implement a first single-location FHEM integration using `HTTPMOD`.
- Validate Rainbow.ai headers, URL shape, JSON parsing, and polling behavior.
- Expose the final compact rain helper readings in FHEM.
- Store one hidden raw payload reading and derive helper readings from it.

### Likely files/modules

- FHEM device definition and attributes `(documented in docs)`
- `docs/rain-nowcast-fhem-httpmod-prototype.md`
- `docs/rain-nowcast-fhem-httpmod-myutils-prototype.md`
- `scripts/99_myUtils_RainNowcastProto.pm.example`
- optional prototype notes under `docs/`

### Build command

```powershell
No standalone build in Phase 2
```

### Verification

- API fetch works with configured key and location.
- JSON fields can be extracted into useful readings.
- One hidden payload reading can be stored and evaluated reliably.
- At least one real automation scenario can consume the resulting readings.
- The selected architecture stays visually compact and maintainable.

### Exit criteria

- One configured location works end-to-end in `HTTPMOD`.
- Required final helper readings exist and are understandable.
- The hidden payload approach with `.raw_json` and `myUtils` works reliably.
- Verification evidence is written to the verification log.

### Current status

- request and authentication path: proven
- raw forecast extraction: proven
- named summary/location readings: proven
- compact top-level state via `stateFormat`: proven
- compact summary device without reading flood: proven
- same-device helper concept via `userReadings` and `myUtils`: proven
- hidden `.raw_json` payload reading: proven
- payload-based helper logic for `rain_now`, `rain_in_minutes`,
  `next_rain_rate`, `next_rain_begin`, `rain_state`, and `fresh_slot_count`:
  proven
- next step: harden the selected architecture and reduce any remaining event or
  maintenance overhead

## Phase 3: Robustness and polish

### Scope

- Improve thresholding, diagnostics, and failure behavior.
- Make the logic easier to tune and reuse.

### Likely files/modules

- Evaluator logic `(path TBD)`
- Diagnostic/readings behavior `(path TBD)`
- Documentation and examples under `docs/`

### Build command

```powershell
No standalone build in Phase 3
```

### Verification

- Verify stable behavior across changing forecast conditions.
- Verify degraded behavior during API failure or malformed responses.

### Exit criteria

- Daily-use robustness is acceptable.
- Diagnostics and configuration are good enough for reuse by others.
