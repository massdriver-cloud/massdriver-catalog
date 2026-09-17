# Azure PostgreSQL Runbook

{{#resources.database}}
| Field | Value |
|---|---|
| Host | `{{resources.database.data.auth.hostname}}` |
| Database | `{{resources.database.data.auth.database}}` |
| Version | `{{resources.database.data.version}}` |
{{/resources.database}}

## An application cannot reach the server

**Diagnosis.** The server answers inside the network only. A client outside the
network gets a timeout, not a refusal.

**Fix.** Run the client inside the network. Check that the private DNS zone
links to the network.

```bash
az network private-dns link vnet list \
  --resource-group <RESOURCE_GROUP> \
  --zone-name <ZONE_NAME> \
  --output table
```

## A deployment fails with `SubnetIsOverlapping` or `DelegationNotFound`

**Diagnosis.** The subnet carries no PostgreSQL delegation, or another service
already uses the subnet.

**Fix.** Give the network a subnet with the PostgreSQL delegation. Azure gives a
delegated subnet to one service only, so that subnet holds nothing else.

## The disk is full

**Symptom.** The server rejects a write with `no space left on device`.

**Fix.** Raise the storage value and deploy again. Azure grows the disk without
downtime.

## Warning: Azure cannot shrink the disk

A smaller value needs a new server, a dump, and a restore. Raise the value only
when you need the space.

## Rotate the administrator password

The bundle creates the password. Deploy the instance again to create a new one.
Every consumer reads the new value from its own connection.

## A failover happened

High availability moves the server to the standby zone. The name stays the same,
so the application reconnects on its own. Check the event.

```bash
az postgres flexible-server show \
  --resource-group <RESOURCE_GROUP> \
  --name <SERVER_NAME> \
  --query "{state:state, zone:availabilityZone, standby:highAvailability.standbyAvailabilityZone}"
```
