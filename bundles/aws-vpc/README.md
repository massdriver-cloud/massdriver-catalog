# AWS VPC

A private network for your serverless workloads.

Most serverless applications do not need a network at all — Lambda runs fine without one. You
need this bundle when a function has to reach something that only exists on a private network,
like a database that is not open to the internet.

## What you get

- A VPC sized by the address range you pick
- A public and a private subnet in each availability zone you asked for
- An internet gateway, so anything in a public subnet can be reached
- Optionally a NAT gateway, so functions in private subnets can call out to the internet
- Flow logs written to CloudWatch, encrypted with their own KMS key
- The default security group stripped of all rules, so nothing can accidentally rely on it

## Choosing an address range

The default `10.0.0.0/16` gives you about 65,000 addresses and is almost always the right
answer. Change it only if this network will one day connect to another network that already
uses that range. You cannot change it after the network is created.

## The NAT gateway question

Turning on **Allow Internet Access from Private Subnets** costs roughly $32/month plus data
charges, and it is the single largest cost in this bundle.

Leave it **off** if your functions only talk to AWS services such as S3, DynamoDB, or Secrets
Manager. Turn it **on** if your functions call third-party APIs — a payment processor, an email
service, an external webhook.

## What connects to this

Anything that needs to live inside the network. In this catalog that is `aws-lambda-app`,
which takes an optional network connection.

## Costs

Without NAT, the network itself is free — you pay only for flow log storage, which is
pennies. With NAT enabled, budget about $32/month plus $0.045 per GB of data processed.
