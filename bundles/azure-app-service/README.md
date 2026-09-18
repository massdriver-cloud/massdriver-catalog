# Azure App Service

This bundle runs a container image on a Linux App Service plan.

## Network

The application joins the subnet of the connected network that carries the App
Service delegation. All outbound traffic goes through that subnet, so the
application reaches a private database and a storage account behind a network
rule.

## Plan sizes

| Size | What you get |
|---|---|
| Basic | One instance, no staging slot, no autoscale. |
| Premium | A staging slot, autoscale, and a faster processor. |

## Connections

| Connection | Required |
|---|---|
| Network | Yes |
| Database | No |
| Storage | No |

## Access to storage

The application holds a system assigned identity, and the bundle assigns the
Azure role that matches the selected policy.
