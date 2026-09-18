# Data Factory Runbook

{{#resources.pipeline}}
| Field | Value |
|---|---|
| Factory | `{{resources.pipeline.data.name}}` |
| Studio | {{resources.pipeline.data.studio_url}} |
| Principal | `{{resources.pipeline.data.principal_id}}` |
{{/resources.pipeline}}

## A pipeline fails with a permission error

**Diagnosis.** The identity of the factory holds no role on the source or on the
target.

**Fix.** Assign the role.

```bash
az role assignment create \
  --assignee <PRINCIPAL_ID> \
  --role "Storage Blob Data Reader" \
  --scope <RESOURCE_ID>
```

## A pipeline cannot reach a private source

**Diagnosis.** The managed network needs a private endpoint to each private
source.

**Fix.** Create the managed private endpoint in the studio, then approve it on
the target resource.

## The first run of a data flow takes four minutes

**Diagnosis.** The cluster was cold.

**Fix.** Raise the idle time. Azure then keeps the cluster warm, and it charges
for that time.

## Warning: the cost of a large runtime

Azure charges per core hour. A 48 core runtime with a 120 minute idle time costs
much more than the pipeline itself.
