# Azure Landing Zone Baseline

This bundle sets the governance floor of a landing zone. Deploy it once per
environment, before any workload.

## What it creates

- A Log Analytics workspace.
- A diagnostic setting that sends the activity log of the subscription to the
  workspace. It covers the administrative, security, policy, and alert
  categories.
- The Defender for Cloud plan of the subscription.
- A security contact, when you give an address.

## What it produces

A `log-workspace` resource. Any bundle that sends diagnostic data consumes it.

## Warning: the Standard plan costs money

The Defender Standard plan charges per resource per month. The Free plan gives
recommendations and a secure score at no charge. Development environments
should use the Free plan.

## Scope

The settings apply to the whole subscription, not to one resource group. Two
instances of this bundle in one subscription fight over the same settings.
Deploy one instance per subscription.
