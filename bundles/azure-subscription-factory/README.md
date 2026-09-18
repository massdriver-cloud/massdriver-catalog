# Azure Subscription Factory

This bundle vends a subscription. The platform team owns it. No application
team deploys it.

## What it creates

- A subscription under the billing scope that you give.
- An association to a management group, which carries the policy set.
- A monthly budget with an alert at 80 percent and at 100 percent.

## What it produces

A `cloud-account` resource. It carries the class of the landing zone, and that
class decides which bundles the projects in the subscription can use.

## Permissions

The service principal needs the `Owner` role on the billing scope, and the
`Management Group Contributor` role on the parent group. A subscription with a
single sandbox credential cannot run this bundle.

## Fields that you cannot change

The name, the class, the management group, the billing scope, and the workload
type. Azure sets all of them at creation.
