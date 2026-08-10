# Register an existing AWS API Gateway HTTP API

Use this form to bring an API gateway that already exists into Massdriver, so other bundles know the URL to call.

You will need the [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) set up for the account that owns the API.

This form is for an **HTTP API** (API Gateway v2). Start by listing what is in the account:

```bash
aws apigatewayv2 get-apis --query 'Items[].{Name:Name,Id:ApiId,Endpoint:ApiEndpoint}' --output table
```

---

### **API ID**

The short identifier AWS assigns the API, such as `abc123xyz`. Take it from the `Id` column above, or:

```bash
aws apigatewayv2 get-apis \
  --query "Items[?Name=='<api-name>'].ApiId" --output text
```

Paste it into **API ID**.

---

### **Endpoint**

The base URL the API is served from. Other bundles append their route paths to this, so do not include a trailing slash.

```bash
aws apigatewayv2 get-api --api-id <api-id> \
  --query 'ApiEndpoint' --output text
```

It looks like `https://abc123xyz.execute-api.us-east-1.amazonaws.com`. Paste it into **Endpoint**.

If the API sits behind a custom domain you own, use that URL instead — it is the one callers should depend on.

---

### **Execution ARN** *(optional)*

This is what a backend uses to confirm that requests are genuinely coming from this API. AWS does not return it directly, so build it:

```bash
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
REGION=$(aws configure get region)
echo "arn:aws:execute-api:${REGION}:${ACCOUNT}:<api-id>"
```

Paste the result into **Execution ARN**.

---

### **Stage** *(optional)*

The stage the endpoint serves. List the stages on the API:

```bash
aws apigatewayv2 get-stages --api-id <api-id> \
  --query 'Items[].StageName' --output table
```

If you see `$default`, use that — it means the URL has no extra path segment on the end. Otherwise use the stage name, and remember that the real URL is then `<endpoint>/<stage>`.

---

### **Region** *(optional)*

The region hosting the API. You can read it out of the endpoint URL — it is the part after `execute-api.`:

```bash
aws apigatewayv2 get-api --api-id <api-id> --query 'ApiEndpoint' --output text \
  | sed 's/.*execute-api\.\([^.]*\)\..*/\1/'
```

Paste it (for example `us-east-1`) into **Region**.
