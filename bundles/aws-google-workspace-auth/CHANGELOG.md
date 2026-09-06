# Changelog

## 0.0.0

First release.

- A Google sign-in door on an API, verified by the gateway itself — signature, issuer, audience
  and expiry are all checked before any endpoint code runs.
- Allowed Workspace domains travel to every connected endpoint, which checks them on a request
  already proven genuine.
- One door can serve many endpoints. Connecting closes an endpoint, disconnecting opens it.

No alarms: an authorizer emits no metrics of its own. Rejected callers are alarmed on the API.
