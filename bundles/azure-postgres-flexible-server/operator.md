---
templating: mustache
---

# PostgreSQL Runbook

## Connect

{{#resources.database}}
```bash
PGPASSWORD='<PASSWORD>' psql \
  -h {{resources.database.auth.hostname}} \
  -p {{resources.database.auth.port}} \
  -U {{resources.database.auth.username}} \
  -d {{resources.database.auth.database}}
```

Run this from a workload inside the network. The server has no public endpoint,
so a client outside the network gets a timeout.
{{/resources.database}}

## An application cannot reach the server

{{#resources.database}}
1. Confirm that the private zone links to the network.
   ```bash
   az network private-dns link vnet list \
     --resource-group <RESOURCE_GROUP> \
     --zone-name <ZONE> \
     --output table
   ```
2. From a pod inside the network, resolve the name.
   ```bash
   nslookup {{resources.database.auth.hostname}}
   ```
   The answer must be a private address of the network.
3. When the name does not resolve, deploy this instance again. The bundle
   recreates the link.
{{/resources.database}}

## A deployment fails with `DelegationNotFound`

The network holds no subnet with the PostgreSQL delegation, or another service
already uses that subnet. Add a delegated subnet to the network, then deploy
again. The bundle stops earlier than Azure does, with a clear message.

## The disk is full

A write fails with `no space left on device`.

1. Raise the storage value in the form and deploy. Azure grows the disk without
   downtime.
2. Azure cannot shrink a disk. A smaller size needs a new server, a dump, and a
   restore.

## Rotate the password

The bundle creates the password. Deploy this instance again to create a new one.
Every consumer then reads the new value through its own connection. Restart each
application that caches a connection string.

## Check a failover

{{#resources.database}}
```bash
az postgres flexible-server show \
  --ids {{resources.database.id}} \
  --query "{state:state, zone:availabilityZone, standby:highAvailability.standbyAvailabilityZone}"
```

The name does not change during a failover, so an application reconnects on its
own.
{{/resources.database}}

## Escalation

- **Team**: Platform Engineering
- **Slack**: #platform-support
