# Address Range Allocation

This bundle records the address range of one network, and it registers that
range with your external IP address management system.

## Why it exists

Two networks with the same range cannot route to each other. A person who picks
a range by hand causes an overlap that appears months later. The management
system owns the ranges, and this bundle keeps Massdriver and that system in
agreement.

## What it produces

A `network-allocation` resource. The `azure-virtual-network` bundle consumes it.

## Registration

Turn on registration and give an endpoint. The bundle then sends a POST request
with the range, the pool, the region, and the owner.

The bundle accepts 200, 201, and 409 from the endpoint. A 409 means that the
record exists already, which is correct on a repeat deployment.

## Adapt it to your system

The request body in `src/main.tf` matches no product. Replace the body and the
headers with the contract of your own system, such as Strata or Infoblox.
