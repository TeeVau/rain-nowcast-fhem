# Scripts

Hier liegen projektspezifische Helfer fuer die FHEM-Integration.

Aktuell relevant:

- `99_myUtils_RainNowcastProto.pm.example`
- `render-social-preview.mjs`

Diese Datei ist als Vorlage fuer `99_myUtils.pm` gedacht und enthaelt die
payload-basierte Auswertung ueber das Hidden-Reading `.raw_json`.

`render-social-preview.mjs` rendert die editierbare SVG-Vorlage unter
`assets/social-preview/` in das finale PNG fuer GitHub Social Preview und die
README-Landingpage.
