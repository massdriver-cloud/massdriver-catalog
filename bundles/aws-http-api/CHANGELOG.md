# Changelog

## 0.0.0

First release.

- One address per application, with endpoints attaching by path.
- Endpoints publish as soon as they attach — no separate release step.
- Request logging, retained for a year by default.
- A per-second rate limit shared by every endpoint behind the address.
- Browser access controlled per origin, open by default while building.
- Alarms for failing requests, floods of rejected callers, and a slow tail.

Works with or without a landing zone; the region is set on the address itself.
