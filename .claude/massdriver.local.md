# Massdriver safety-hook config

production_pattern: ^(prod|production|prd)$

Match the **environment slug only** (the second segment of `<project>-<env>-<component>`), not the project or the component. Pure equality against the three canonical production strings keeps the LLM-based safety hook from flagging component IDs like `pg`, `db`, or `api` as production.
