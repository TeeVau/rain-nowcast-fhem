# rain-nowcast-fhem Funktionsspezifikation (FSD)

## 1. Zielbild

`rain-nowcast-fhem` stellt fuer einen konfigurierten Standort lokale Regen-Nowcast-Informationen in FHEM bereit. Die Daten werden ueber Rainbow.ai bezogen, per `HTTPMOD` gespeichert und in `myUtils` zu kompakten, automationsfreundlichen Readings verdichtet.

Die erste Version soll fuer deutsche FHEM-Nutzer sofort im Alltag brauchbar sein, insbesondere fuer:

- Dachfenster-Warnungen
- Tuer- oder Balkontuer-Warnungen
- Markisen- oder Beschattungslogik
- Giess-Sperren bei bevorstehendem Regen

## 2. Architektur

### 2.1 Zielarchitektur

Die Implementierung bleibt innerhalb vorhandener FHEM-Bausteine:

- ein `HTTPMOD`-Device fuer den API-Abruf
- ein verstecktes Reading `.raw_json` fuer den letzten Nutzpayload
- Ableitungslogik in `99_myRainNowcastUtils.pm`
- kompakte Ziel-Readings ueber `userReadings`
- optionale Warnlogik ueber `notify`

### 2.2 Datenfluss

1. FHEM startet einen periodischen Abruf.
2. `HTTPMOD` ruft Rainbow.ai fuer einen festen Standort ab.
3. Der aktuelle JSON-Payload wird in `.raw_json` gehalten.
4. `myUtils` wertet `forecast[]` aus.
5. `userReadings` schreiben reduzierte Ziel-Readings auf dasselbe Device.
6. `notify` kann auf diese Readings oder auf Kontakt-Events reagieren.

## 3. Funktionsumfang

### 3.1 Muss-Anforderungen

- Abruf von Rainbow.ai-Nowcast-Daten ueber `HTTPMOD`
- Nutzung eines API-Keys ueber Request-Header
- Auswertung eines einzelnen Standorts pro Device
- Ableitung von Zeitpunkt und Staerke des ersten relevanten Regens
- Bereitstellung kompakter Readings auf demselben FHEM-Device
- keine Abhaengigkeit von einem projektspezifischen Custom-Modul

### 3.2 Soll-Anforderungen

- moeglichst robuste Ableitung trotz schwankender Forecast-Laengen
- erklaerbares Verhalten ueber Logging und nachvollziehbare Readings
- spaeter leicht erweiterbar fuer weitere Regeln
- FHEMWEB-taugliche Darstellung ueber `stateFormat` und optional `devStateIcon`

## 4. Readings

### 4.1 Kern-Readings

| Reading | Bedeutung |
|---|---|
| `summary_intensity` | zusammengefasste Intensitaet aus Rainbow.ai |
| `latitude` | Rueckgabewert fuer den abgefragten Standort |
| `longitude` | Rueckgabewert fuer den abgefragten Standort |
| `.raw_json` | versteckter aktueller API-Payload |
| `rain_now` | `1`, wenn relevanter Regen bereits im ersten frischen Slot liegt |
| `rain_in_minutes` | Minuten bis zum ersten relevanten Regen |
| `next_rain_rate` | Intensitaet des ersten relevanten Regens |
| `next_rain_type` | Niederschlagsart des ersten relevanten Regens |
| `next_rain_begin` | Startzeit des ersten relevanten Regens |
| `rain_state` | `dry`, `rain_now`, `rain_soon` oder `later_rain` |
| `fresh_slot_count` | Anzahl der aus dem aktuellen Payload ausgewerteten Slots |

### 4.2 Anzeige

Das Device soll trotz Nowcast-Logik kompakt bleiben:

- keine hunderten sichtbaren `forecast_<nn>_*`-Readings
- nutzbarer `stateFormat`
- optional Wetter-Icons ueber `devStateIcon`

## 5. Warnlogik

### 5.1 Ziel

Zusatzlogik fuer Sprachwarnungen soll ohne neue Devices und ohne neue Persistenz-Readings funktionieren.

### 5.2 Unterstuetzte Faelle

#### Fall A: `rain_update`

Wenn ein `RainNowcastProto`-Update zeigt, dass Regen im konfigurierten Zeitfenster ansteht und mindestens ein relevanter Kontakt offen ist, wird ein Warntext erzeugt.

#### Fall B: `contact_open`

Wenn ein relevanter Kontakt geoeffnet wird und bereits Regen im konfigurierten Zeitfenster ansteht, wird sofort ein Warntext erzeugt.

### 5.3 Automatische Kontakterkennung

Die Warnlogik erkennt relevante Devices automatisch ueber:

- `devspec2array("a:IsRoofWindow=1")`
- `devspec2array("NAME=.*_Kontakt_Tuer.*")`

Interpretation:

- `IsRoofWindow=1` bedeutet Dachfenster
- Device-Namen mit `_Kontakt_Tuer` bedeuten Tuer-Kontakte
- Dachfenster gelten bei `open` oder `tilted` als offen
- Tueren gelten bei `open` als offen

### 5.4 Textausgabe

Der Anzeigetext verwendet:

1. bevorzugt das FHEM-`alias`
2. sonst den Device-Namen

Typische Meldungen:

- `Achtung, Regen in 12 Minuten. Offen sind Fenster Bad und Fenster Buero. Bitte schliessen.`
- `Achtung, Fenster Arbeitszimmer ist geoeffnet und Regen ist in 8 Minuten angesagt.`

## 6. Randbedingungen

### 6.1 Technische Randbedingungen

- Logik laeuft lokal in FHEM
- externer Dienst nur fuer den API-Abruf
- ein Standort pro Device
- keine Historie in v1

### 6.2 Risiken

- API-Ausfall oder unvollstaendige Payloads
- Forecast-Schwankungen mit instabilen Triggerpunkten
- veraltete Readings aus alten `forecast_<nn>_*`-Expansionen bei falscher Architektur

### 6.3 Gegenmassnahmen

- Auswertung nur des aktuellen `.raw_json`
- kompaktes Reading-Modell
- Logging fuer Warnpfade und Fehlersituationen

## 7. Verifikation

Die Loesung gilt als erfolgreich, wenn folgende Punkte im Live-System nachvollziehbar funktionieren:

1. `HTTPMOD` kann Rainbow.ai erfolgreich abrufen.
2. `userReadings` erzeugen die Kern-Readings korrekt.
3. `rain_in_minutes` passt sichtbar zum Payload.
4. `rain_update` meldet offene relevante Kontakte korrekt.
5. `contact_open` meldet geoeffnete relevante Kontakte korrekt.
6. Nicht relevante oder geschlossene Kontakte fuehren nicht zu falschen Meldungen.

## 8. Dokumentationsbezug

Die zugehoerigen Arbeitsdokumente im Repo sind:

- `docs/rain-nowcast-fhem-idea.md`
- `docs/rain-nowcast-fhem-httpmod-myutils-prototype.md`
- `scripts/99_myRainNowcastUtils.pm`
