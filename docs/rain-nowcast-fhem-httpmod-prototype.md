# rain-nowcast-fhem HTTPMOD Prototype

This document captures the first feasibility prototype for Rainbow.ai access in
FHEM with the built-in `HTTPMOD` module.

## Goal

Document the early discovery steps that proved Rainbow.ai nowcast data can be
fetched and exposed in FHEM with `HTTPMOD`.

This document now serves as the evidence trail for how the final architecture
was selected.

The early prototype focused on:

- request URL shape
- authentication header handling
- JSON extraction behavior
- initial reading names
- polling behavior

## API basis

Preferred endpoint for the prototype:

- `GET https://api.rainbow.ai/nowcast/v1/precip-global/<longitude>/<latitude>`

Required header:

- `Ocp-Apim-Subscription-Key: <APIKEY>`

Recommended header:

- `Accept: application/json`

## Prototype variant A: discovery-first

Use this first to inspect how `HTTPMOD` exposes the Rainbow.ai JSON structure.

```text
define RainNowcastProto HTTPMOD https://api.rainbow.ai/nowcast/v1/precip-global/<longitude>/<latitude> 300
attr RainNowcastProto enableControlSet 1
attr RainNowcastProto requestHeader01 Accept: application/json
attr RainNowcastProto requestHeader02 Ocp-Apim-Subscription-Key: <APIKEY>
attr RainNowcastProto extractAllJSON 1
attr RainNowcastProto stateFormat { ReadingsVal($name,"summary_intensity","init") }
```

Why this is useful:

- `HTTPMOD` uses GET if no request data is configured
- `extractAllJSON` makes the first response structure visible quickly
- the first useful paths can be discovered directly from generated readings

Expected immediate readings:

- `latitude`
- `longitude`
- `summary_intensity`
- additional `forecast...` readings depending on how `HTTPMOD` expands arrays

## Prototype variant B: named readings

Once the generated JSON paths are known from variant A, switch to named
readings.

```text
define RainNowcastProto HTTPMOD https://api.rainbow.ai/nowcast/v1/precip-global/<longitude>/<latitude> 300
attr RainNowcastProto enableControlSet 1
attr RainNowcastProto requestHeader01 Accept: application/json
attr RainNowcastProto requestHeader02 Ocp-Apim-Subscription-Key: <APIKEY>
attr RainNowcastProto reading01Name summary_intensity
attr RainNowcastProto reading01JSON summary_intensity
attr RainNowcastProto reading02Name latitude
attr RainNowcastProto reading02JSON latitude
attr RainNowcastProto reading03Name longitude
attr RainNowcastProto reading03JSON longitude
attr RainNowcastProto stateFormat { ReadingsVal($name,"summary_intensity","init") }
```

Notes:

- `summary_intensity` is the easiest first sanity check
- forecast-array extraction should be refined only after variant A reveals the
  actual JSON path names created by `HTTPMOD`
- if `extractAllJSON 1` remains enabled, the named readings are added, but the
  full flattened forecast readings still remain visible

## Candidate next-step readings

After discovery, the following helper readings were identified as the useful
target set:

- `rain_in_minutes`
- `rain_intensity`
- `rain_window`
- `forecast_age_s`
- `api_status`

## Manual verification

1. Create the prototype device in FHEM with variant A.
2. Trigger `set RainNowcastProto reread`.
3. Confirm that the request succeeds and JSON-based readings appear.
4. Inspect the generated forecast-related reading names.
5. Decide whether array extraction is straightforward enough for meaningful
   derived rain logic.
6. Move to variant B and named readings.
7. Decide how the final helper logic should remain compact on the same device.

## Observed result on 2026-05-02

The discovery-first prototype worked successfully in a live FHEM instance.

Observed structure:

- `summary_intensity` is exposed directly as a simple reading
- forecast array entries are flattened into numbered readings such as:
  - `forecast_01_precipRate`
  - `forecast_01_precipType`
  - `forecast_01_timestampBegin`
  - `forecast_01_timestampEnd`
  - `forecast_100_precipRate`
  - `forecast_100_precipType`
  - `forecast_100_timestampBegin`
  - `forecast_100_timestampEnd`

Observed behavior from the shared test run:

- early forecast entries were `no_precipitation` with `precipRate = 0`
- later entries such as `forecast_100` onward switched to `rain`
- `summary_intensity` was `intense`
- the API payload is therefore directly useful for a first automation-oriented
  feasibility step in FHEM

Initial conclusion:

- Rainbow.ai access through `HTTPMOD` is proven
- JSON extraction through `extractAllJSON` is proven
- forecast array flattening is readable enough to continue experimentation
- the next practical step is not request debugging anymore, but derivation of
  compact helper readings from the discovered forecast structure

## Architecture result from the discovery phase

The early discovery work led to a clear result:

- `HTTPMOD` is fully suitable as the request and presentation device
- visible indexed forecast readings are not a good final storage model
- final evaluator logic should operate on one hidden raw payload reading
- helper readings should stay on the same device via `userReadings` and
  `myUtils`

## Observed result from variant B on 2026-05-02

Variant B also worked in the live setup.

Key observations:

- HTTP request succeeded with `HTTP/1.1 200 OK`
- `summary_intensity`, `latitude`, and `longitude` were available as named
  readings
- `stateFormat` already worked and produced `STATE = heavy`
- all flattened `forecast_<nn>_*` readings were still present because
  `extractAllJSON 1` was still enabled
- some higher-index `forecast_<nn>_*` readings remained with older timestamps
  from earlier updates

Important interpretation:

Variant B does not yet reduce the reading count. It currently behaves as:

- named high-value readings for quick access
- plus full raw forecast expansion for discovery/debugging

That is not a bug. It is the expected result while `extractAllJSON 1` stays
active.

There is, however, one real prototype risk:

- old indexed forecast readings may remain if a later API response contains
  fewer forecast entries than an earlier one

Any derivation logic must therefore avoid blindly scanning to the highest
existing `forecast_<nn>_*` index without checking freshness and continuity.

## Practical interpretation after variant B

At that stage, the prototype had already shown that the current device was good
enough to answer:

- when does rain start?
- how strong is the first relevant rain cell?
- is it raining now, soon, or later?

## Suggested target readings from the discovery phase

Based on the confirmed raw structure, the following compact readings were
identified as useful:

- `rain_now`
- `rain_in_minutes`
- `next_rain_rate`
- `next_rain_type`
- `next_rain_begin`
- `state`

Suggested semantics:

- `rain_now`: `1` if the first forecast slot already contains rain with
  relevant rate, else `0`
- `rain_in_minutes`: minutes until the first forecast slot with rain above a
  defined threshold
- `next_rain_rate`: precip rate of the first relevant rain slot
- `next_rain_type`: usually `rain` or `no_precipitation`
- `next_rain_begin`: timestamp of the first relevant rain slot
- `state`: compact human-readable state such as `dry`, `rain_now`,
  `rain_soon`, or `later_rain`

## Observed result from variant B without `extractAllJSON` on 2026-05-02

Variant B without `extractAllJSON` also worked successfully.

Observed behavior:

- visible `READINGS` were reduced to the explicitly configured named readings:
  - `summary_intensity`
  - `latitude`
  - `longitude`
- `STATE` still resolved cleanly via `stateFormat`
- the user-facing reading flood disappeared

Important interpretation:

Disabling `extractAllJSON` is currently the cleanest way to keep the prototype
device readable in daily use.

At the same time, it changes the role of the device:

- good for a compact status device
- not sufficient as the only source for forecast-slot-based helper logic,
  because the raw `forecast_<nn>_*` readings are no longer available in
  `READINGS`

The `list` output still showed old internal HTTPMOD bookkeeping structures such
as `defptr.readingBase` entries for former forecast readings. For the current
prototype decision, the practically relevant part is:

- the active `READINGS` set is compact
- the raw forecast slots are no longer directly consumable as readings

## Updated architecture recommendation

The final selected architecture is now:

1. Keep one compact HTTPMOD device.
2. Store the current response payload in hidden reading `.raw_json`.
3. Derive helper readings on the same device via `userReadings` and `myUtils`.
4. Avoid scanning visible `forecast_<nn>_*` readings in the final evaluator.

## Same-device architecture

The selected v1 design is:

- keep one single `HTTPMOD` device
- let that device perform the Rainbow.ai request
- store the current response payload in `.raw_json`
- derive the compact helper readings on that same device via `userReadings`
- parse the payload in `myUtils`

### Why this works

Relevant FHEM/HTTPMOD building blocks:

- `HTTPMOD` can parse JSON directly into readings
- JSON path specifications can also be interpreted as regex patterns
- `userReadings` can create derived readings on the same device
- `HTTPMOD` stores the last HTTP response internally as `httpbody`; according
  to the documentation it is visible when `showBody` is enabled

This avoids the two main problems from the earlier variants:

- hundreds of visible forecast storage readings
- stale leftover indexed readings across updates

- this is already custom Perl logic, just not yet a dedicated module
- parsing internals like `httpbody` should be treated as a deliberate design
  choice and verified carefully in practice

## Final recommendation from the discovery phase

The early discovery phase ultimately established this direction:

1. keep the compact HTTPMOD variant without `extractAllJSON`
2. store the current response payload in hidden reading `.raw_json`
3. derive helper readings on the same device via `userReadings`
4. evaluate the payload in `myUtils`
