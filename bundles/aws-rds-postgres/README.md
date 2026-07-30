# Postgres Database

A PostgreSQL database for your app to store real, relational data in — users, orders, whatever your app needs to remember between requests.

## Why RDS and not Aurora Serverless

Aurora Serverless v2 sounds appealing for small apps because it scales down when idle — but it has a floor. Even at its minimum (0.5 ACU), you're paying for roughly $44/month of compute before you've stored a single row, plus separate storage and I/O charges. A small provisioned instance (`db.t4g.micro`, the `xs` size here) runs about a quarter of that for workloads this size, with no scaling behavior to reason about.

If one of your apps outgrows "small" — sustained high traffic, unpredictable bursty load — that's the moment to reconsider Aurora Serverless for that specific app. Don't default to it just because it sounds more modern.

## What you get

- A private database — it's never reachable from the public internet, only from inside your network.
- Encrypted storage by default.
- An optional standby copy in a second availability zone (`multi_az`) for automatic failover — turn this on before you have real users depending on uptime.
- Deletion protection on by default, so nobody deletes this by accident. Turn it off only for a database you're intentionally going to tear down.

## Things you can't change later

`database_name` and `username` are locked in once deployed — the password is generated and rotated for you, and it never shows up anywhere except at deploy time.

## Customize it

1. Edit `massdriver.yaml` to change instance sizing, storage limits, or version support.
2. `src/main.tf` is real Terraform/OpenTofu provisioning an actual RDS instance — not a placeholder.
3. Update `operator.md` with your team's real failover and restore procedures.

See the [catalog README](../../README.md) and [Bundle YAML Spec](https://docs.massdriver.cloud/guides/bundle-yaml-spec) for more.
