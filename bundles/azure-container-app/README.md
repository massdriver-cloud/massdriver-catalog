# Azure Container App

This bundle runs a container image on Azure Container Apps.

## Network

The environment sits inside the subnet of the connected network that carries the
Container Apps delegation. Azure needs a range of /23 or larger for that subnet.

Turn off public ingress to accept traffic from inside the network only.

## Connections

| Connection | Required | What the application receives |
|---|---|---|
| Network | Yes | The subnet that holds the environment. |
| Database | No | The host, the port, the name, the user, and the password. |
| Storage | No | The account, the container, and the endpoint. |

## Access to storage

The application holds a system assigned identity. The bundle assigns the Azure
role that matches the selected policy. No access key exists.

## Scale

Azure starts a copy under load, up to the maximum. A minimum of 0 costs nothing
while the application is idle, and the first request then waits for a cold start.
