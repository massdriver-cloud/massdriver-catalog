# Register an existing AWS Lambda function

Use this form to bring a Lambda function that already exists into Massdriver, so an API gateway or another bundle can call it.

You will need the [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) set up for the account that owns the function.

First, list the functions in the account so you can find the one you want:

```bash
aws lambda list-functions --query 'Functions[].FunctionName' --output table
```

Then pull the details for it once and read the values off that output:

```bash
aws lambda get-function --function-name <function-name>
```

---

### **Function ARN**

This is the full identity of the function.

```bash
aws lambda get-function --function-name <function-name> \
  --query 'Configuration.FunctionArn' --output text
```

It looks like `arn:aws:lambda:us-east-1:123456789012:function:my-api`. Paste it into **Function ARN**.

---

### **Invoke ARN**

This one is easy to get wrong: it is **not** the same string as the Function ARN. An API gateway needs this longer form to route requests to the function.

AWS does not return it directly, so build it from the Function ARN:

```bash
FN_ARN=$(aws lambda get-function --function-name <function-name> \
  --query 'Configuration.FunctionArn' --output text)
REGION=$(echo "$FN_ARN" | cut -d: -f4)
echo "arn:aws:apigateway:${REGION}:lambda:path/2015-03-31/functions/${FN_ARN}/invocations"
```

Paste the result into **Invoke ARN**.

---

### **Function Name**

The short name, not the ARN — for example `my-api`. Anything that wants to invoke this function needs the name to attach a permission.

Paste it into **Function Name**.

---

### **Region** *(optional)*

The region the function runs in. It is the fourth colon-separated field of the Function ARN:

```bash
aws lambda get-function --function-name <function-name> \
  --query 'Configuration.FunctionArn' --output text | cut -d: -f4
```

Paste it (for example `us-east-1`) into **Region**.

---

### **Execution Role ARN** *(optional)*

The IAM role the function runs as. Fill this in if you want other bundles to be able to grant this function access to their resources.

```bash
aws lambda get-function --function-name <function-name> \
  --query 'Configuration.Role' --output text
```

---

### **Runtime** *(optional)*

The language runtime, for example `python3.12` or `nodejs20.x`.

```bash
aws lambda get-function --function-name <function-name> \
  --query 'Configuration.Runtime' --output text
```

---

### **Code Bucket** and **Code Object Key** *(optional)*

Fill these in only if the function's code is loaded from S3 rather than uploaded directly. They tell deploy tooling where to put new code.

```bash
aws lambda get-function --function-name <function-name> \
  --query 'Configuration.[FunctionName]' --output text
aws lambda get-function-configuration --function-name <function-name>
```

If the function was published from a zip file in S3, use that bucket name and object key. If you are not sure, leave both blank.
