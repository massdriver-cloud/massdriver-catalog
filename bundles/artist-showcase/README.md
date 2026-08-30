# artist-showcase

The public roster page. Reads the artist list, and nothing else.

## What makes this one different

Every other application in this catalog owns a schema and writes to it. This one owns nothing. It
holds a single login that was granted read access to one table — `artist_portal.artists` — and it
has no second connection, no schema, and no way to write anywhere.

That is the point. A page on the open internet should be able to do exactly one thing, and you
should be able to prove which thing by looking at the grant rather than by reading the code.

## Why a developer has to place it

The component carries `exposure: external`. Citizen developers hold `project:design` conditioned on
`exposure: internal`, so adding a component marked external is denied for them. Placing this is a
developer or operator act.

Worth being precise about what that gates and what it does not: the condition stops a citizen
developer from *adding a component declared external*. It does not reach inside the bundle's
parameters. Somebody determined enough could place an internal component and turn its
`public_access` on. If you want that closed too, the answer is a repository grant that keeps
internet-facing bundles out of citizen projects entirely.

## Where the data comes from

A `pg-table-access` component in the platform project issues the login:

```
login_name: showcase_public
read:
  - artist_portal.artists
```

The artists team owns that table. The grant is issued from the platform project, so it is the
platform team who agreed to publish it, not the team that wanted to.

Take the table off that list and the page stops working on the next deploy. That is the intended
way to unpublish the roster — it is one line, in a reviewable place, with a deployment history.

## An internal tool and a public site in one project

`artists` holds both this and Artist Portal. The portal is internal and writes to the schema; this
is external and reads one table of it.

That combination is why `exposure` is a component attribute rather than a project one. On projects
it would force a team to split in two the first time they wanted a public page next to their
internal tool.
