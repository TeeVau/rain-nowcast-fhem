# rain-nowcast-fhem

[![Status](https://img.shields.io/badge/status-praxiserprobt-2ea44f)](https://github.com/TeeVau/rain-nowcast-fhem)
[![Zielgruppe](https://img.shields.io/badge/Zielgruppe-deutsche%20FHEM--Nutzer-1f6feb)](https://github.com/TeeVau/rain-nowcast-fhem)
[![Technik](https://img.shields.io/badge/FHEM-HTTPMOD%20%2B%20myUtils-ffb000)](https://github.com/TeeVau/rain-nowcast-fhem)
[![Lizenz](https://img.shields.io/github/license/TeeVau/rain-nowcast-fhem)](LICENSE)
[![GitHub Stars](https://img.shields.io/github/stars/TeeVau/rain-nowcast-fhem?style=social)](https://github.com/TeeVau/rain-nowcast-fhem/stargazers)

![rain-nowcast-fhem social preview](assets/social-preview/rain-nowcast-fhem-social-preview.png)

Lokale Regen-Nowcast-Logik fuer FHEM. Das Projekt holt Rainbow.ai-Daten per `HTTPMOD`, wertet sie in `myUtils` aus und stellt daraus kompakte, automationsfreundliche Readings für FHEM-Installationen bereit.

## Ueberblick

Statt Wetter-Apps manuell zu pruefen, bekommst du direkt in FHEM nutzbare Zustandswerte wie:

- `rain_now`
- `rain_in_minutes`
- `next_rain_rate`
- `next_rain_type`
- `next_rain_begin`
- `rain_state`
- `summary_intensity`

Darauf aufbauend lassen sich alltagstaugliche Automationen bauen, zum Beispiel:

- Warnungen fuer geoeffnete Dachfenster
- Warnungen fuer Tueren oder Balkontueren
- Markisen- oder Beschattungslogik
- Giess-Sperren bei bevorstehendem Regen

## ## Architektur

Die Loesung bleibt absichtlich schlank:

1. `HTTPMOD` holt die Nowcast-Daten fuer einen festen Standort.
2. Der aktuelle Payload wird in `.raw_json` gespeichert.
3. `99_myRainNowcastUtils.pm` wertet `forecast[]` aus.
4. `userReadings` schreiben kompakte Ziel-Readings auf dasselbe Device zurueck.
5. `notify` kann daraus Sprachwarnungen oder weitere Aktionen ableiten.

Die Warnlogik erkennt automatisch:

- Dachfenster ueber `attr <device> IsRoofWindow 1`
- Tueren ueber Device-Namen mit `_Kontakt_Tuer`

Fuer Ansagetexte wird bevorzugt das FHEM-`alias` 

## So sieht das in FHEMWEB aus

![Beispielstatus in FHEMWEB](assets/readme/fhem-state-example.png)

Das Device bleibt kompakt, zeigt aber trotzdem direkt den aktuellen Regenzustand und die naechste relevante Aenderung in lesbarer Form an.

## Schnellstart

Du brauchst:

- einen Rainbow.ai API-Key
- ein FHEM-Device auf Basis von `HTTPMOD`
- die Hilfsfunktionen in `99_myRainNowcastUtils.pm`
- `userReadings` auf demselben Device

Der technische Einstiegspunkt ist:

- [HTTPMOD + myUtils Setup](docs/rain-nowcast-fhem-httpmod-myutils-prototype.md)



## Beispiel-Nutzen im Alltag

- `rain_update`: Regen ist in den naechsten 30 Minuten angesagt und mindestens ein Dachfenster steht offen.
- `contact_open`: Ein Dachfenster oder eine Tuer wird geoeffnet, waehrend Regen bereits fuer die naechsten 30 Minuten ansteht.

Die Funktion `myRainNowcastWarnIfNeeded(...)` deckt beide Faelle ab und kann direkt aus `notify` aufgerufen werden.

## Dokumentation

- [Idea](docs/rain-nowcast-fhem-idea.md)
- [FSD](docs/rain-nowcast-fhem-fsd.md)
- [HTTPMOD + myUtils Setup](docs/rain-nowcast-fhem-httpmod-myutils-prototype.md)

## Lizenz

Dieses Projekt steht unter der [MIT-Lizenz](LICENSE).
