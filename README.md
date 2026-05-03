# rain-nowcast-fhem

![rain-nowcast-fhem social preview](assets/social-preview/rain-nowcast-fhem-social-preview.png)

Lokale Regen-Nowcast-Logik fuer FHEM, damit dein Smart Home nicht raten muss, ob in 3 Minuten Regen kommt.

`rain-nowcast-fhem` nutzt die Rainbow.ai Nowcast API, holt die Daten per
`HTTPMOD` in FHEM und leitet daraus kompakte, automationsfreundliche Readings
wie `rain_now`, `rain_in_minutes` oder `rain_state` ab. Darauf aufbauend
lassen sich auch schlanke `notify`-Warnungen fuer Alexa oder andere
TTS-Devices aufsetzen.

## Warum dieses Projekt?

Kurzfristige Regenvorhersagen sind heute gut genug, um echte
Automationsentscheidungen zu treffen. In der Praxis bedeutet das aber oft noch:
App oeffnen, Radar checken, Intensitaet einschaetzen, selbst entscheiden.

Dieses Projekt nimmt dir genau diesen manuellen Schritt ab und macht die
Information direkt in FHEM nutzbar. Das ist besonders praktisch fuer:

- Dachfenster-Warnungen
- Markisen- oder Beschattungslogik
- Giess-Sperren bei bevorstehendem Regen
- Benachrichtigungen, wenn es gleich losgeht

## Was du bekommst

Die Loesung zielt auf ein kompaktes FHEM-Device mit wenigen, klaren Readings:

- `rain_now`: sagt dir, ob es gerade relevant regnet
- `rain_in_minutes`: Minuten bis zum ersten relevanten Regen
- `next_rain_rate`: Intensitaet des naechsten relevanten Regen-Slots
- `next_rain_type`: Niederschlagsart des naechsten relevanten Slots
- `next_rain_begin`: Startzeit des naechsten relevanten Regens
- `rain_state`: kompakter Zustand wie `dry`, `rain_now`, `rain_soon` oder `later_rain`
- `summary_intensity`: zusammengefasste Intensitaet aus der API

Damit kannst du in FHEM direkt auf alltagstaugliche Zustandswerte reagieren,
statt selbst JSON oder Hunderte Forecast-Readings auszuwerten.

Optional kannst du dieselben Readings direkt fuer Warnungen nutzen, zum
Beispiel:

- Alexa-Ansage, wenn Regen in 30 Minuten kommt und ein Dachfenster offen ist
- Alexa-Ansage, wenn eine Balkontuer geoeffnet wird und Regen bereits bald
  ansteht

## So funktioniert es

Die Architektur ist bewusst einfach gehalten:

1. `HTTPMOD` holt die Rainbow.ai Nowcast-Daten fuer einen festen Standort.
2. Der aktuelle Payload wird in einem versteckten Reading `.raw_json`
   gespeichert.
3. `myUtils` wertet daraus das `forecast[]`-Array aus.
4. `userReadings` schreiben kompakte Ziel-Readings zurueck auf dasselbe
   FHEM-Device.

Darueber hinaus kann eine kleine Funktion in `myUtils` dieselben Readings per
`notify` fuer sprachbasierte Warnungen auswerten, ohne neue Readings oder
weitere FHEM-Devices einzufuehren.

Das Ergebnis ist eine lokale, nachvollziehbare FHEM-Loesung ohne eigenes
Custom-Device-Modul.

## Schnellstart

Wenn du bereits FHEM nutzt, brauchst du fuer den Einstieg nur diese Bausteine:

- einen Rainbow.ai API-Key
- ein `HTTPMOD`-Device fuer den Request
- die Hilfsfunktionen in `99_myUtils.pm`
- `userReadings`, die die Zielwerte auf dem gleichen Device erzeugen

Der technische Einstiegspunkt dafuer ist:

- [HTTPMOD + myUtils Setup](docs/rain-nowcast-fhem-httpmod-myutils-prototype.md)

Dort findest du die aktuelle Beispielkonfiguration fuer:

- `summary_intensity`, `latitude`, `longitude`
- das versteckte `.raw_json`
- `rain_now`, `rain_in_minutes`, `next_rain_rate`, `next_rain_begin`,
  `rain_state` und `fresh_slot_count`
- eine notify-aufrufbare Warnfunktion fuer geoeffnete Fenster oder Tueren

## Mehr technische Details

Wenn du tiefer einsteigen oder die Loesung nachvollziehen willst:

- [FSD](docs/rain-nowcast-fhem-fsd.md)
- [Phase Plan](docs/rain-nowcast-fhem-phase-plan.md)
- [Verification Log](docs/rain-nowcast-fhem-verification-log.md)
- [HTTPMOD + myUtils Setup](docs/rain-nowcast-fhem-httpmod-myutils-prototype.md)

## Contributing

Kleine, saubere Verbesserungen sind willkommen. Wenn du etwas am Verhalten,
den Readings oder der Architektur aenderst, halte bitte auch die passende Doku
aktuell.

Mehr dazu steht in [CONTRIBUTING.md](CONTRIBUTING.md).

## Lizenz

Vor einem echten Public Release sollte noch eine saubere Open-Source-Lizenz
ergaenzt werden. Aktuell ist noch keine Lizenzdatei im Repository enthalten.
