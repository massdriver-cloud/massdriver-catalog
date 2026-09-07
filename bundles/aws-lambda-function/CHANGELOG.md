# Changelog

## 0.0.0

First release.

- An endpoint on a shared address, taking a method and path.
- A connected table is required; connecting one grants access to that table alone and passes its
  name in as a setting.
- A sign-in policy is optional. Connecting one closes the endpoint, disconnecting it opens it.
- A landing zone is optional, needed only to reach private addresses.
- Ships with a working example that reads and writes the table, so the endpoint answers before
  any image exists. Switches to a team's own image without changing anything else.
- A ceiling on simultaneous requests, so one endpoint cannot consume the account's capacity.
- Alarms for errors, refused requests, and a slow tail approaching the timeout.
