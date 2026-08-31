# artist-showcase runbook

## The page says the roster is not available

The footer carries the reason. Three causes, in order of likelihood.

**The grant was removed.** Somebody took `artist_portal.artists` off the `read` list on the
`pg-table-access` component that issues this login. The error names a permission problem on that
table. If the roster was meant to come down, this is working correctly.

**The login was rotated.** Redeploying `pg-table-access` generates a new password, and this app
keeps the old one until it is redeployed too:

```bash
mass instance deploy artists-dev-showcase -m "pick up rotated credential" -f
```

**The database is unreachable.** Confirm the `vpc_connector` slot is connected. Without it Cloud
Run has no route to a private address and the connection hangs until it times out.

## The page is empty but says 0 acts

The connection worked and the table has no rows. The Artist Portal seeds itself on its first
request, so open the portal once and reload this.

## Adding a component fails with a permission error

Expected, if you are signed in as a citizen developer. This component is `exposure: external`, and
citizen groups hold `project:design` only where `exposure` is `internal`.

Place it as a developer or an operator. This is the control working, not a bug.

## Confirming what this site can actually reach

Connected as the administrative user, in pgAdmin:

```sql
SELECT table_schema, table_name, privilege_type
FROM information_schema.role_table_grants
WHERE grantee = 'showcase_public'
ORDER BY table_schema, table_name;
```

It should return exactly one row group: `artist_portal.artists`, `SELECT`, and nothing else. Any
`INSERT`, `UPDATE` or `DELETE` here is worth chasing — a public page should not have them.

## Taking the roster offline

Remove `artist_portal.artists` from the `read` list on the `pg-table-access` component and
redeploy it. The grant is revoked and this page starts reporting that the roster is unavailable.

Decommissioning this app also works and is cleaner if it is coming down for good, but revoking the
grant is the faster of the two and leaves an obvious trail.

## Decommission

Removes the Cloud Run service and its runtime identity. No data is touched — this app owns none.
The login it used belongs to the `pg-table-access` component and outlives this one.
