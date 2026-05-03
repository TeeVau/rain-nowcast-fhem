# Skripte

In diesem Ordner liegen die projektspezifischen Helfer für die FHEM-Integration.

## Relevante Dateien

- `99_myRainNowcastUtils.pm`

## 99_myRainNowcastUtils.pm

Diese Datei enthält die eigentliche Ableitungslogik für:

- Payload-Auswertung aus `.raw_json`
- Regen-Readings wie `rain_in_minutes` oder `rain_state`
- optionale Warnlogik für `rain_update` und `contact_open`

Die Datei ist als Vorlage für deine FHEM-Einrichtung gedacht und wird dort als `99_myRainNowcastUtils.pm` eingebunden.
