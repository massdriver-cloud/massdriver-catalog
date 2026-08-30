# PostgreSQL Database

A place for your app to store data. This gives you a managed PostgreSQL database that only your
own apps can reach — it has no public address, so nothing on the open internet can find it or try
to log into it.

## What you get

- A PostgreSQL database, ready to connect to.
- A generated username and password, stored safely and handed to your app automatically — you
  never type or copy a password by hand.
- Daily backups, so you can recover from a mistake (like an accidental delete) by going back to an
  earlier point in time.
- Encrypted connections, always.

## What you don't need to think about

This database connects to your platform's private network automatically. You will never be asked
to pick a network, an IP range, or anything like that — that part is handled for you.

## Settings

**How much traffic do you expect?** — Small, Medium, or Large. This picks the underlying computer
size for you. You can move up to a bigger size later without losing any data.

**How much data will you store?** — Just a starting point in gigabytes. It grows automatically as
you add data, so it's fine to start small and not worry about running out of room.

**Region** — Where in the world this database runs. Use the same region as the app that talks to
it, so requests stay fast.

**Keep the database running if something goes wrong at Google's end?** — When this is on, a live
standby copy takes over automatically if there's a problem. It roughly doubles the cost. Turn it
on for anything real people depend on; it's fine to leave off for a side project.

**Keep daily backups?** — Leave this on unless you have a specific reason not to. It lets you
recover data from an earlier point in time.

**Prevent accidental deletion?** — When this is on, nobody (including this tool) can delete the
database by mistake. Only turn it off if you're intentionally tearing this down soon, like a
short-lived test.

**Database Name / Username** — What the database and its login are called. These can't be changed
after the database is created — if you need different ones, create a new database instead.

**PostgreSQL Version** — Which version of PostgreSQL to run. If you're not sure, use the
recommended one. This can't be changed after creation.

## Connecting your app to it

Wire your app's component to this one on the canvas. Your app receives the hostname, port,
database name, username, and password automatically — there's nothing to copy and paste, and the
password is never shown in plain text outside of what your app receives at deploy time.
