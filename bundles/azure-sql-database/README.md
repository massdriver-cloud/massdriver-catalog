# Azure SQL Database

This bundle creates a SQL server and one database.

## Network

The server accepts traffic from the subnets of the connected network only. The
bundle creates one network rule per subnet, and it opens no firewall rule to the
internet. The subnets need the `Microsoft.Sql` service endpoint.

## Service levels

| Level | Notes |
|---|---|
| Basic | About 5 dollars per month. It holds 2 GiB at most. |
| Standard | A DTU model. It suits a steady small load. |
| General purpose | A vCore model. It scales without downtime. |

A precondition stops a deployment that asks for more than 2 GiB on the Basic
level, because Azure rejects it.

## Audit

The bundle turns on the extended audit policy and keeps the record for 90 days.

## Fields that you cannot change

The database name and the administrator username.
