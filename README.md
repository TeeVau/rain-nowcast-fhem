# rain-nowcast-fhem

![rain-nowcast-fhem social preview](assets/social-preview/rain-nowcast-fhem-social-preview.png)

Lokale Regen-Nowcast-Logik für FHEM, damit dein Smart Home nicht raten muss, ob in 3 Minuten Regen kommt.

`rain-nowcast-fhem` nutzt die Rainbow.ai Nowcast API, holt die Daten per
`HTTPMOD` in FHEM und leitet daraus kompakte, automationsfreundliche Readings
wie `rain_now`, `rain_in_minutes` oder `rain_state` ab. Darauf aufbauend
lassen sich auch schlanke `notify`-Warnungen für Alexa oder andere
TTS-Devices aufsetzen.

## Warum dieses Projekt?

Kurzfristige Regenvorhersagen sind heute gut genug, um echte
Automationsentscheidungen zu treffen. In der Praxis bedeutet das aber oft noch:
App öffnen, Radar checken, Intensität einschätzen, selbst entscheiden.

Dieses Projekt nimmt dir genau diesen manuellen Schritt ab und macht die
Information direkt in FHEM nutzbar. Das ist besonders praktisch für:

- Dachfenster-Warnungen
- Markisen- oder Beschattungslogik
- Giess-Sperren bei bevorstehendem Regen
- Benachrichtigungen, wenn es gleich losgeht

## Was du bekommst

Die Lösung zielt auf ein kompaktes FHEM-Device mit wenigen, klaren Readings:

- `rain_now`: sagt dir, ob es gerade relevant regnet
- `rain_in_minutes`: Minuten bis zum ersten relevanten Regen
- `next_rain_rate`: Intensität des nächsten relevanten Regen-Slots
- `next_rain_type`: Niederschlagsart des nächsten relevanten Slots
- `next_rain_begin`: Startzeit des nächsten relevanten Regens
- `rain_state`: kompakter Zustand wie `dry`, `rain_now`, `rain_soon` oder `later_rain`
- `summary_intensity`: zusammengefasste Intensität aus der API

Damit kannst du in FHEM direkt auf alltagstaugliche Zustandswerte reagieren,
statt selbst JSON oder Hunderte Forecast-Readings auszuwerten.

Optional kannst du dieselben Readings direkt für Warnungen nutzen, zum
Beispiel:

- Alexa-Ansage, wenn Regen in 30 Minuten kommt und ein Dachfenster offen ist
- Alexa-Ansage, wenn eine Balkontür geöffnet wird und Regen bereits bald
  ansteht

## So funktioniert es

Die Architektur ist bewusst einfach gehalten:

1. `HTTPMOD` holt die Rainbow.ai Nowcast-Daten für einen festen Standort.
2. Der aktuelle Payload wird in einem versteckten Reading `.raw_json`
   gespeichert.
3. `myUtils` wertet daraus das `forecast[]`-Array aus.
4. `userReadings` schreiben kompakte Ziel-Readings zurück auf dasselbe
   FHEM-Device.

Darüber hinaus kann eine kleine Funktion in `myUtils` dieselben Readings per
`notify` für sprachbasierte Warnungen auswerten, ohne neue Readings oder
weitere FHEM-Devices einzuführen.

Das Ergebnis ist eine lokale, nachvollziehbare FHEM-Lösung ohne eigenes
Custom-Device-Modul.

## Schnellstart

Wenn du bereits FHEM nutzt, brauchst du für den Einstieg nur diese Bausteine:

- einen Rainbow.ai API-Key
- ein `HTTPMOD`-Device für den Request
- die Hilfsfunktionen in `99_myRainNowcastUtils.pm`
- `userReadings`, die die Zielwerte auf dem gleichen Device erzeugen

Der technische Einstiegspunkt dafür ist:

- [HTTPMOD + myUtils Setup](docs/rain-nowcast-fhem-httpmod-myutils-prototype.md)

Dort findest du die aktuelle Beispielkonfiguration für:

- `summary_intensity`, `latitude`, `longitude`
- das versteckte `.raw_json`
- `rain_now`, `rain_in_minutes`, `next_rain_rate`, `next_rain_begin`,
  `rain_state` und `fresh_slot_count`
- eine notify-aufrufbare Warnfunktion für geöffnete Fenster oder Türen

## Mehr technische Details

Wenn du tiefer einsteigen oder die Lösung nachvollziehen willst:

- [FSD](docs/rain-nowcast-fhem-fsd.md)
- [Phase Plan](docs/rain-nowcast-fhem-phase-plan.md)
- [Verification Log](docs/rain-nowcast-fhem-verification-log.md)
- [HTTPMOD + myUtils Setup](docs/rain-nowcast-fhem-httpmod-myutils-prototype.md)

## Contributing

Kleine, saubere Verbesserungen sind willkommen. Wenn du etwas am Verhalten,
den Readings oder der Architektur änderst, halte bitte auch die passende Doku
aktuell.

Mehr dazu steht in [CONTRIBUTING.md](CONTRIBUTING.md).

## Lizenz

Dieses Projekt steht unter der [MIT-Lizenz](LICENSE).
