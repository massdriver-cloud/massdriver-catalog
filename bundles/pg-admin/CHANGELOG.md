# Changelog

## 0.0.0

Initial release.

- The published `dpage/pgadmin4` image, built into the platform's own registry
- Server list and passfile written at boot from the injected connection, since Cloud Run keeps no disk
- Pinned to exactly one instance, because pgAdmin's session is local to the container
- Internal-only by default
