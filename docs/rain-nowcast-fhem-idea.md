# rain-nowcast-fhem Projektidee

## Kurzfassung

`rain-nowcast-fhem` soll Rainbow.ai-Nowcast-Daten lokal in FHEM nutzbar machen und daraus einfache, robuste Regen-Readings fuer Automationen ableiten.

## Problem

Kurzfristige Regenvorhersagen sind heute gut genug, um echte Entscheidungen im Alltag zu treffen. In vielen Setups bleibt der letzte Schritt aber manuell:

1. Wetter-App oeffnen
2. Radar oder Nowcast ansehen
3. selbst entscheiden, ob gleich gehandelt werden muss

Fuer FHEM ist das unpraktisch. Dort werden klar benannte, maschinenlesbare Zustandswerte gebraucht.

## Ziel

Das Projekt soll aus Rainbow.ai-Daten direkt nutzbare FHEM-Readings erzeugen, zum Beispiel:

- regnet es jetzt schon?
- in wie vielen Minuten beginnt relevanter Regen?
- wie stark wird der erste relevante Regenslot?
- ist eine Warnung fuer geoeffnete Dachfenster oder Tueren sinnvoll?

## Zielgruppe

Die Loesung richtet sich an deutsche FHEM-Nutzer, die:

- Smart-Home-Logik lokal halten wollen
- vorhandene FHEM-Bausteine wie `HTTPMOD`, `notify` und `myUtils` nutzen
- wetterabhaengige Automationen ohne Cloud-Logik aufbauen wollen

## Erwarteter Nutzen

Der konkrete Mehrwert liegt in kleinen, aber alltagstauglichen Automationen:

- Dachfenster-Warnungen
- Tuer- oder Balkontuer-Warnungen
- Markisen- oder Beschattungslogik
- Giess-Sperren
- spaetere Folgeautomationen auf Basis derselben Readings

## Technischer Ansatz

Die Loesung bleibt bewusst einfach:

- ein `HTTPMOD`-Device pro Standort
- ein verstecktes Reading `.raw_json`
- Ableitungslogik in `99_myRainNowcastUtils.pm`
- kompakte Ziel-Readings ueber `userReadings`
- optionale Sprachwarnungen ueber `notify`

## Nicht-Ziele der aktuellen Version

- mehrere Standorte in einer einzigen Instanz
- historische Auswertung
- eigene GUI
- ein projektspezifisches FHEM-Custom-Modul
- Fokus auf andere Smart-Home-Systeme als FHEM
