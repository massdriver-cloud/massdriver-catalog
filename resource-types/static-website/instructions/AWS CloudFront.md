# Register an existing CloudFront website

Use this form to bring a website that already exists into Massdriver, so other things can link
to its address.

You will need the [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
set up for the account that owns the distribution.

Start by listing the distributions in the account:

```bash
aws cloudfront list-distributions \
  --query 'DistributionList.Items[].{Id:Id,Domain:DomainName,Comment:Comment}' --output table
```

---

### **Distribution ID**

The short identifier, such as `E2QWRUHAPOMQZL`. Take it from the `Id` column above.

Paste it into **Distribution ID**.

---

### **URL**

The address people visit. Take the `Domain` value from the same table and put `https://` in
front of it:

```bash
aws cloudfront get-distribution --id <distribution-id> \
  --query 'Distribution.DomainName' --output text
```

That gives something like `d111111abcdef8.cloudfront.net`, so you enter
`https://d111111abcdef8.cloudfront.net`.

If the site is reached through a domain you own, use that address instead — it is the one
people actually depend on.

---

### **Content Bucket** *(optional)*

The bucket the distribution reads files from:

```bash
aws cloudfront get-distribution-config --id <distribution-id> \
  --query 'DistributionConfig.Origins.Items[].DomainName' --output text
```

The result looks like `my-site-bucket.s3.us-east-1.amazonaws.com`. Enter only the bucket name
from the front of it, for example `my-site-bucket`.

---

### **Region** *(optional)*

The region the content bucket lives in. Read it from the same origin name above — it is the
part after `.s3.` — or ask for it directly:

```bash
aws s3api get-bucket-location --bucket <bucket-name> --query LocationConstraint --output text
```

If that prints `None`, the region is `us-east-1`.
