# rain-nowcast-fhem HTTPMOD + myUtils Prototype

This document describes the selected v1 architecture: keep one `HTTPMOD`
device and derive compact helper readings on that same device via
`userReadings` and a small helper in `myUtils`.

## Goal

Expose a compact, automation-friendly reading set on the existing
`RainNowcastProto` device with one hidden raw payload reading and without any
custom FHEM device module.

## Prototype files

Example helper source in this repository:

- `scripts/99_myRainNowcastUtils.pm`

This is an example source file for the FHEM `99_myRainNowcastUtils.pm`
workflow. It is not
auto-loaded from this repository as-is.

## Prototype approach

The helper functions operate on one hidden raw payload reading on the same
`HTTPMOD` device:

- `.raw_json`

This reading is intended to hold the complete response body or, defensively,
the response text from which the JSON body can be extracted.

This matters because a broad regex such as `(\{.*\})` may also capture JSON
snippets from HTTP headers before the actual response body. The helper
therefore extracts the final decodable JSON document defensively.

Important safeguard:

- the helper decodes one single current payload instead of scanning hundreds of
  `forecast_<nn>_*` storage readings
- this avoids stale leftover indexed readings from older updates
- the same helper file can also expose a notify-callable warning function
  without adding extra FHEM readings or devices

## Suggested FHEM setup

Keep the existing compact device and store the raw response in `.raw_json`
while testing the helper logic.

This is the selected v1 setup because it keeps:

- one real HTTP request device
- one hidden raw payload reading for debugging and parsing
- the compact derived helper readings on that same device

## Ready-to-paste configuration for the current prototype device

The following block is based on the already proven live device shape
`RainNowcastProto`:

```text
attr RainNowcastProto icon weather_rain_meter
attr RainNowcastProto devStateIcon RN.dry:weather_sun@yellow RN.rain_now:weather_rain_heavy@blue RN.rain_soon:weather_rain@blue RN.later_rain:weather_cloudy
attr RainNowcastProto reading01JSON summary_intensity
attr RainNowcastProto reading01Name summary_intensity
attr RainNowcastProto reading02JSON latitude
attr RainNowcastProto reading02Name latitude
attr RainNowcastProto reading03JSON longitude
attr RainNowcastProto reading03Name longitude
attr RainNowcastProto reading90Name .raw_json
attr RainNowcastProto reading90Regex (\{.*\})
attr RainNowcastProto reading90RegOpt s
attr RainNowcastProto requestHeader01 Accept: application/json
attr RainNowcastProto requestHeader02 Ocp-Apim-Subscription-Key: <YOUR_KEY>
attr RainNowcastProto userReadings \
  rain_now:summary_intensity.* { myRainNowcastNow($name,0.1) },\
  rain_in_minutes:summary_intensity.* { myRainNowcastMinutes($name,0.1) },\
  next_rain_rate:summary_intensity.* { myRainNowcastRate($name,0.1) },\
  next_rain_type:summary_intensity.* { myRainNowcastType($name,0.1) },\
  next_rain_begin:summary_intensity.* { myRainNowcastBegin($name,0.1) },\
  rain_state:summary_intensity.* { myRainNowcastState($name,0.1) },\
  fresh_slot_count:summary_intensity.* { myRainNowcastFreshSlotCount($name) }
attr RainNowcastProto stateFormat { myRainNowcastStateFormat($name) }
```

Suggested manual refresh after loading the helper:

```text
reload 99_myRainNowcastUtils.pm
set RainNowcastProto reread
```

If the weather icons do not appear in FHEMWEB yet, refresh the icon set once:

```text
attr WEB iconPath fhemSVG:openautomation:default
set WEB rereadicons
```

Why the `RN:` prefix?

- this follows the proven FHEM multi-line `stateFormat` plus `devStateIcon`
  pattern where the first line is only a hidden marker for the icon regex
- `RN.dry` in `devStateIcon` matches the first line `RN:dry`
- the second line starts with `<br/>`, so the readable text is rendered below
  the icon instead of being folded into the icon line

## Expected result on the same device

After the refresh, the same `RainNowcastProto` device should expose both:

- the fixed device icon `weather_rain_meter`
- a `devStateIcon` that maps `dry`, `rain_now`, `rain_soon`, and
  `later_rain` to weather icons
- a second visible state line with German state labels such as
  `Regen bald leicht (in 12 Min.)`
- compact summary readings such as `summary_intensity`
- the hidden payload reading `.raw_json`
- derived helper readings such as `rain_in_minutes` and `rain_state`

This keeps the setup inspectable without splitting the logic across multiple
FHEM devices.

## Meaning of the helper readings

- `rain_now`: `1` if the first fresh slot already contains relevant rain
- `rain_in_minutes`: minutes until the first relevant fresh rain slot
- `next_rain_rate`: precip rate of the first relevant fresh rain slot
- `next_rain_type`: precip type of the first relevant fresh rain slot
- `next_rain_begin`: local timestamp of the first relevant fresh rain slot
- `rain_state`: `dry`, `rain_now`, `rain_soon`, or `later_rain`
- `fresh_slot_count`: number of currently trusted fresh forecast slots
- `myRainNowcastStateFormat($name)`: returns the multi-line FHEMWEB `STATE`
  string used by `devStateIcon` plus the translated user-facing status text

## Optional warning helper for Alexa or TTS

The example helper file also contains a notify-callable function:

- `myRainNowcastWarnIfNeeded($triggerKind, $rainDevice, $sourceDevice, $speakCb, $opts)`

This function does not create new readings. It only evaluates the existing
rain helper state and, if needed, returns or speaks a warning text.

Expected arguments:

- `$triggerKind`: `rain_update` or `contact_open`
- `$rainDevice`: the HTTPMOD nowcast device such as `RainNowcastProto`
- `$sourceDevice`: the opening contact device for `contact_open`, otherwise
  `undef`
- `$speakCb`: callback that receives the final warning text
- `$opts`: optional hashref, currently intended for `threshold` and
  `rain_window_minutes`

For debugging, you can also pass `logLevel`, for example:

```text
{ myRainNowcastWarnIfNeeded("rain_update", "RainNowcastProto", undef, undef, { rain_window_minutes => 200, logLevel => 3 }) }
```

This writes the decision path into the FHEM log via `Log3`.

Two useful live test calls are:

```text
{ myRainNowcastWarnIfNeeded("rain_update", "RainNowcastProto", undef, undef, { rain_window_minutes => 200 }) }
```

```text
{ myRainNowcastWarnIfNeeded("contact_open", "RainNowcastProto", "az_Kontakt_Fenster1", undef, { rain_window_minutes => 200, logLevel => 3 }) }
```

The warning helper now discovers the monitored devices automatically via
`DEVSPEC`:

- `devspec2array("a:IsRoofWindow=1")`
- `devspec2array("NAME=.*_Kontakt_Tuer.*")`

Interpretation:

- roof windows are treated as open on `open` or `tilted`
- `_Kontakt_Tuer` devices are treated as open on `open`

For spoken warnings, the helper now uses the FHEM `alias` attribute of each
configured device. If no `alias` is set, it falls back to the device name.

## Notify examples

The warning helper is designed for two small `notify` rules.

### 1. Ready-to-paste notify: warn on RainNowcast updates if something is already open

```text
define n_rain_warn_open notify ^RainNowcastProto:rain_in_minutes:.*$ {
  myRainNowcastWarnIfNeeded(
    "rain_update",
    "RainNowcastProto",
    undef,
    sub {
      my ($text) = @_;
      fhem("set AlexaTTS speak $text");
    }
  );
}
```

This covers the case:

- the RainNowcast device refreshed `rain_in_minutes`
- rain is expected within the next 30 minutes
- at least one auto-detected roof-window or `_Kontakt_Tuer` device is open

### 2. Ready-to-paste notify: warn immediately when a monitored contact opens before rain

```text
define n_rain_warn_contact_open notify .:(open|tilted|state: open|state: tilted)$ {
  myRainNowcastWarnIfNeeded(
    "contact_open",
    "RainNowcastProto",
    $NAME,
    sub {
      my ($text) = @_;
      fhem("set AlexaTTS speak $text");
    }
  );
}
```

This covers the case:

- any contact-like device emits an open or tilted event
- the existing nowcast readings already indicate rain within the next
  30 minutes
- `closed` events are intentionally ignored and should not be part of the
  notify regex

The helper returns an empty string when no warning is required, so a matching
notify event without relevant rain or without a configured contact stays quiet.

Adjust before use:

- replace `AlexaTTS` with your real speak or Alexa device
- set `attr <device> IsRoofWindow 1` on every roof-window device you want to
  include
- ensure your door device name contains `_Kontakt_Tuer`
- if your contact devices use plain `open|closed` events, keep the notify
  regex narrow and do not include `closed`

## Threshold assumption

The example uses `0.1` as the first rain relevance threshold for `precipRate`.
This is only a prototype default and should be tuned with real observations.

## Recommended test sequence

1. Copy the helper functions into your FHEM `99_myRainNowcastUtils.pm`.
2. Reload `99_myRainNowcastUtils.pm` in FHEM.
3. Add the `userReadings` attribute to `RainNowcastProto`.
4. Optionally add one or both warning `notify` rules.
5. Trigger `set RainNowcastProto reread`.
6. Inspect:
   - `rain_now`
   - `rain_in_minutes`
   - `next_rain_rate`
   - `rain_state`
   - `fresh_slot_count`
   - `STATE` via `stateFormat`
7. Compare the derived values with the JSON payload inside `.raw_json`.
8. Verify the warning helper:
   - open a configured roof window or door while rain is within 30 minutes
   - trigger a RainNowcast reread and verify the spoken warning
   - open a configured contact while `rain_in_minutes <= 30` and verify the
     immediate spoken warning
   - open an unconfigured contact or simulate `rain_in_minutes > 30` and verify
     that no warning is spoken
9. Verify that stale older forecast-slot leftovers are no longer relevant,
   because the helper evaluates only the current payload.

## First live decision rule to verify

For the first live check, the helper should behave like this:

- if slot 1 already contains relevant rain, `rain_now = 1` and
  `rain_state = rain_now`
- if the first relevant rain slot is within 15 minutes,
  `rain_state = rain_soon`
- if no relevant rain slot exists in the fresh forecast window,
  `rain_state = dry`

## Architecture result

This approach is now the selected project architecture for v1:

- one compact HTTPMOD device
- one hidden `.raw_json` payload reading
- helper logic in `myUtils`
- helper state exposure on the same device via `userReadings`
