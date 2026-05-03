# rain-nowcast-fhem Verification Log

Use this file as the evidence trail for Codex-driven work.

## Environment

- Date:
- Machine:
- Toolchain:
- Board/device:
- Serial port/device:

## Runs

| Time | Phase | Command/Test | Result | Evidence | Follow-up |
|---|---|---|---|---|---|
| 2026-05-02 | Phase 1 | Idea/FSD/phase-plan review | Passed | Idea, FSD, phase plan, and traceability now exist and are aligned to the project goal. | Start HTTPMOD-based integration planning. |
| 2026-05-02 | Phase 2 planning | Architecture review against Rainbow.ai and FHEM docs | Passed | Rainbow.ai nowcast access is documented as GET-based and looks feasible for an HTTPMOD-based implementation. | Prepare the first HTTPMOD prototype. |
| 2026-05-02 | Phase 2 setup | HTTPMOD prototype draft | Passed | Prototype configuration and manual checks documented in `docs/rain-nowcast-fhem-httpmod-prototype.md`. | Try the prototype in a live FHEM instance and record observed reading paths. |
| 2026-05-02 | Phase 2 live test | HTTPMOD variant A with `extractAllJSON` | Passed | Live readings confirm `summary_intensity` and flattened `forecast_<nn>_*` reading families such as `forecast_100_precipRate` and `forecast_100_precipType`. | Use the discovery result to refine the compact target architecture. |
| 2026-05-02 | Phase 2 live test | HTTPMOD variant B with named readings and `stateFormat` | Passed | Named readings `summary_intensity`, `latitude`, and `longitude` work; `STATE` is already derived meaningfully; raw forecast expansion remains available while `extractAllJSON 1` is enabled. | Compare compactness and derivation options. |
| 2026-05-02 | Phase 2 live test | Reading persistence review | Warning noted | Some higher forecast indices remained with older timestamps after later updates, indicating leftover indexed raw readings from previous responses. | Avoid indexed-reading-based evaluator logic in the final design. |
| 2026-05-02 | Phase 2 live test | HTTPMOD variant B without `extractAllJSON` | Passed | Visible readings collapsed to `summary_intensity`, `latitude`, and `longitude`; the user-facing device became compact and readable. | Use a compact same-device architecture and restore evaluator input through a hidden raw payload reading. |
| 2026-05-02 | Phase 2 design refinement | Same-device `HTTPMOD + userReadings + myUtils` concept | Passed | The architecture was documented as one HTTPMOD device with helper logic on the same device. | Replace indexed-reading parsing with payload-based parsing. |
| 2026-05-02 | Phase 2 implementation prep | Hidden `.raw_json` payload approach identified | Passed | HTTPMOD can store the response text in one hidden reading, keeping the device clean while preserving evaluator input. | Rework the helper functions to parse `.raw_json`. |
| 2026-05-02 | Phase 2 implementation prep | myUtils helper updated for `.raw_json` | Passed | Example helper functions now read `.raw_json`, extract the final decodable JSON document defensively, and evaluate `forecast[]` directly. | Verify the live helper readings from the payload-based evaluator. |
| 2026-05-02 | Phase 2 live validation | Payload-based helper readings with `.raw_json` | Passed | Live results showed `fresh_slot_count = 238`, `rain_now = 1`, `rain_in_minutes = 0`, `next_rain_begin` aligned to the current minute, `next_rain_rate = 49.127`, and `rain_state = rain_now` while `summary_intensity = extreme`. | Lock the v1 architecture to HTTPMOD + myUtils + `.raw_json` and update all docs accordingly. |
| 2026-05-02 | Phase 2 documentation | FSD and phase plan migrated to final architecture | Passed | The FSD and phase plan now describe HTTPMOD + `userReadings` + `myUtils` + hidden `.raw_json` as the selected v1 solution. | Align the remaining project docs to the same final model. |

## Open verification gaps

- API contract and payload structure are grundsaetzlich validiert, aber noch
  nicht vollstaendig gegen Rand- und Fehlerfaelle geprueft.
- No standalone syntax check of the final helper code has been executed in a
  local Perl/FHEM runtime from this workspace.
- Threshold tuning for practical automation use is still open.
- Event suppression and final daily-use reading hygiene still need a small
  cleanup pass.
- Error-state behavior for malformed payloads or API outages still needs a
  concrete live validation run.
