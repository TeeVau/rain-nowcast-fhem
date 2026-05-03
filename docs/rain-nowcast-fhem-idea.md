# rain-nowcast-fhem Project Idea

## One-sentence goal

Implement a local FHEM smart-home logic that uses the Rainbow.ai Nowcast API
to derive actionable short-term rain states for home automation decisions.

## Problem and user value

The primary user is the project owner, with the project intended to be
published on GitHub afterward for reuse by others.

Today, short-term rain forecasts are available through mobile apps and are
already reliable enough for manual decision-making, but the workflow is still
manual: open app, inspect radar, interpret timing and intensity, and decide
whether action is needed.

The expected improvement is a local automation layer in FHEM that translates
high-resolution nowcast data into clear, decision-relevant states such as:

- rain expected in X minutes
- expected rain intensity
- usable dry window / rain window

This should make automations like awning control, notifications, and watering
locks possible in a robust and explainable way.

## Target environment

- Hardware: Smart-home environment with relevant actuators/sensors in home use
  `(details open)`
- Firmware/framework: FHEM automation logic
- Host/application: Local smart-home installation
- Network/protocols: Rainbow.ai Nowcast API over network connection `(assumed:
  HTTPS/API access)`
- Power source: Not a primary design driver for this project `(assumed)`

## Inputs and outputs

| Direction | Item | Notes |
|---|---|---|
| Input | Rainbow.ai nowcast forecast data | High-resolution short-term rain forecast for the configured location; exact payload and fields still to be documented. |
| Input | API key | Credential required to access the Rainbow.ai API. |
| Input | Concrete location | The specific place for which the nowcast should be evaluated. |
| Output | FHEM device readings | The system shall expose relevant weather states through readings on one HTTPMOD-based FHEM device. |
| Output | Decision-relevant FHEM states | Examples: "rain in X minutes", rain intensity, rain window, and automation triggers or inhibit states. |

## Success criteria

- A local FHEM logic can evaluate nowcast data and expose useful states for at
  least one real automation scenario.
- The system can warn about relevant near-term weather changes with enough lead
  time to support actions like closing roof windows.
- Thresholds, polling intervals, and logic structure are robust enough to avoid
  obviously noisy or impractical behavior.

## Constraints

- Cost: Should primarily use existing local smart-home infrastructure.
- Size/enclosure: Not relevant for the first software-focused version.
- Power/battery: Not relevant for the first software-focused version.
- Privacy/security: Logic should run locally in FHEM; exact API credential and
  data-handling constraints still to be documented.
- Offline behavior: Needs clarification for API outage or connectivity loss.

## Known unknowns

- Exact Rainbow.ai API contract, fields, and authentication details
- Polling interval strategy
- Threshold model for "relevant rain"
- Exact representation of states and readings inside FHEM
- Which first automation scenarios are mandatory for version 1

## Nice-to-have ideas

- Explainable readings or debug output showing why a weather state changed
- Reusable GitHub-ready structure for other FHEM users
- Easily extendable logic for additional automation rules

## Explicitly not in v1

- Multiple locations
- Historical analysis
