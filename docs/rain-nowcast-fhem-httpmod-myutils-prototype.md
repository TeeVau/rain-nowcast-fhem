# rain-nowcast-fhem HTTPMOD + myUtils Einrichtung

## Ziel

Dieses Dokument beschreibt die aktuelle, empfohlene FHEM-Integration für `rain-nowcast-fhem`.

Die Zielarchitektur besteht aus:

- einem `HTTPMOD`-Device
- einem versteckten Reading `.raw_json`
- Ableitungslogik in `99_myRainNowcastUtils.pm`
- optionalen Warnungen über `notify`

## Relevante Dateien

- `scripts/99_myRainNowcastUtils.pm`
- `README.md`
- `docs/rain-nowcast-fhem-fsd.md`

## Grundidee

Der aktuelle Rainbow.ai-Payload wird nicht in viele einzelne Forecast-Readings aufgefächert und dort ausgewertet, sondern gezielt über ein verstecktes `.raw_json` verarbeitet.

Das reduziert:

- visuelles Reading-Chaos
- veraltete Forecast-Reste aus alten Abrufen
- unnötige Komplexität in `notify` und `userReadings`

## Beispielkonfiguration für `RainNowcastProto`

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

Falls FHEMWEB die Wetter-Icons noch nicht kennt:

```text
attr WEB iconPath fhemSVG:openautomation:default
set WEB rereadicons
```

## Erwartete Readings

Das Device soll danach unter anderem folgende Readings liefern:

- `summary_intensity`
- `.raw_json`
- `rain_now`
- `rain_in_minutes`
- `next_rain_rate`
- `next_rain_type`
- `next_rain_begin`
- `rain_state`
- `fresh_slot_count`

## Reload und erster Test

```text
reload 99_myRainNowcastUtils.pm
set RainNowcastProto reread
```

Danach solltest du prüfen:

- ob `.raw_json` befüllt wird
- ob `rain_in_minutes` und `rain_state` plausibel sind
- ob `stateFormat` einen lesbaren Status erzeugt

## Warnfunktion

Die Datei `99_myRainNowcastUtils.pm` enthält zusätzlich:

```perl
myRainNowcastWarnIfNeeded($triggerKind, $rainDevice, $sourceDevice, $speakCb, $opts)
```

### Parameter

- `$triggerKind`: `rain_update` oder `contact_open`
- `$rainDevice`: Name des RainNowcast-Devices, z. B. `RainNowcastProto`
- `$sourceDevice`: auslösender Kontakt bei `contact_open`, sonst `undef`
- `$speakCb`: Callback für die Ausgabe an Alexa oder ein Speak-Device
- `$opts`: optional, z. B. `threshold`, `rain_window_minutes`, `logLevel`

### Beispielaufrufe in der FHEM-Konsole

```text
{ myRainNowcastWarnIfNeeded("rain_update", "RainNowcastProto", undef, undef, { rain_window_minutes => 200 }) }
```

```text
{ myRainNowcastWarnIfNeeded("contact_open", "RainNowcastProto", "az_Kontakt_Fenster1", undef, { rain_window_minutes => 200, logLevel => 3 }) }
```

### Debug-Variante

```text
{ myRainNowcastWarnIfNeeded("rain_update", "RainNowcastProto", undef, undef, { rain_window_minutes => 200, logLevel => 3 }) }
```

Mit `logLevel` schreibt die Funktion ihren Entscheidungsweg ins FHEM-Log.

## Automatische Kontakterkennung

Die Warnlogik erkennt relevante Devices automatisch über `DEVSPEC`:

- `devspec2array("a:IsRoofWindow=1")`
- `devspec2array("NAME=.*_Kontakt_Tuer.*")`

Interpretation:

- `IsRoofWindow=1` kennzeichnet Dachfenster
- Device-Namen mit `_Kontakt_Tuer` kennzeichnen Türen
- Dachfenster sind bei `open` oder `tilted` offen
- Türen sind bei `open` offen

Für die Ansagetexte wird bevorzugt `alias` verwendet.

## Notify-Beispiele

### 1. Warnung bei RainNowcast-Update

```text
define n_rain_warn_open notify RainNowcastProto:rain_in_minutes:.* {
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
attr n_rain_warn_open NOTIFYDEV RainNowcastProto
```

### 2. Warnung beim Öffnen eines Kontakts

```text
define n_rain_warn_contact_open notify (az_Kontakt_Fenster1|bk_Kontakt_Tuer1):(open|tilted):.* {
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
attr n_rain_warn_contact_open NOTIFYDEV az_Kontakt_Fenster1,bk_Kontakt_Tuer1
```

Wichtig:

- `closed` sollte nicht in der Regex stehen
- `AlexaTTS` musst du gegen dein echtes Speak-Device austauschen
- vermeide bewusst breite Muster wie `.:(open|tilted)...`, weil sie auf sehr viele FHEM-Events anspringen können
- begrenze `notify` zusätzlich über `NOTIFYDEV`, damit nur relevante Devices überhaupt ausgewertet werden

## Empfohlene Live-Prüfung

1. `set RainNowcastProto reread`
2. Rohdaten in `.raw_json` prüfen
3. `rain_in_minutes` mit dem Payload vergleichen
4. `rain_update` mit offenem Dachfenster testen
5. `contact_open` mit einem echten Kontakt-Device testen
6. bei Bedarf `logLevel => 3` oder `4` zuschalten

## Ergebnis

Mit dieser Architektur bekommst du:

- ein kompaktes FHEM-Device
- nachvollziehbare Regen-Readings
- keine unnötigen Forecast-Reading-Fluten
- einfache Sprachwarnungen auf Basis derselben Readings
