# Scripts

In diesem Ordner liegen die projektspezifischen Helfer fuer die FHEM-Integration.

## Relevante Dateien

- `99_myRainNowcastUtils.pm`
- `render-social-preview.mjs`

## 99_myRainNowcastUtils.pm

Diese Datei enthaelt die eigentliche Ableitungslogik fuer:

- Payload-Auswertung aus `.raw_json`
- Regen-Readings wie `rain_in_minutes` oder `rain_state`
- optionale Warnlogik fuer `rain_update` und `contact_open`

Die Datei ist als Vorlage fuer dein FHEM-Setup gedacht und wird dort als
`99_myRainNowcastUtils.pm` eingebunden.

## render-social-preview.mjs

Dieses Skript rendert die SVG-Vorlage aus `assets/social-preview/` in das PNG,
das im GitHub-README verwendet wird.
