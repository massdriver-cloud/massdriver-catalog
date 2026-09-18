---
templating: mustache
---

# Data Factory Runbook

## Health check

{{#resources.pipeline}}
```bash
az datafactory pipeline-run query-by-factory \
  --factory-name {{resources.pipeline.name}} \
  --resource-group {{resources.pipeline.name}} \
  --last-updated-after $(date -u -v-1d +%Y-%m-%dT%H:%M:%SZ) \
  --last-updated-before $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --query "value[].{pipeline:pipelineName, status:status}" --output table
```

Open the pipelines at {{resources.pipeline.studio_url}}.
{{/resources.pipeline}}

## A pipeline fails with a permission error

The identity of the factory holds no role on the source or on the target. A
pipeline fails at run time, not at deployment time.

{{#resources.pipeline}}
```bash
az role assignment create \
  --assignee {{resources.pipeline.principal_id}} \
  --role "Storage Blob Data Reader" \
  --scope <RESOURCE_ID>
```

```bash
az role assignment list --assignee {{resources.pipeline.principal_id}} --output table
```
{{/resources.pipeline}}

## A pipeline cannot reach a private source

The managed network needs a private endpoint to each private source.

1. Create the managed private endpoint in the studio.
2. Approve it on the target resource.
   ```bash
   az network private-endpoint-connection list --id <TARGET_RESOURCE_ID> --output table
   ```
3. Run the pipeline again.

## The first run of a data flow takes four minutes

The cluster was cold. Raise the idle time in the form, and Azure then keeps the
cluster warm. Azure charges for that time.

## The compute bill grows

Azure charges per core hour while a data flow runs. A 48 core runtime with a 120
minute idle time costs far more than the pipeline moves. Lower the cores, or
lower the idle time.

## Escalation

- **Team**: Data Platform
- **Slack**: #platform-support
