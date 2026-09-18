# Azure Database for PostgreSQL

This bundle creates a flexible server, one database, and a private DNS zone.

## Network

The server has no public endpoint. It sits inside the subnet of the connected
network that carries the PostgreSQL delegation. Only a workload inside the
network can reach it.

The bundle fails with a clear message when the network holds no delegated
subnet.

## Fields that you cannot change

- **PostgreSQL version.** A major version upgrade needs a maintenance window.
- **Database name** and **administrator username**.
- **Geo redundant backup.** Azure sets this option at creation only.

## Backups

Azure keeps a backup for the retention period. Turn on the geo redundant option
to keep a copy in the paired region.
