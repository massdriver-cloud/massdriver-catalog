---
templating: mustache
---

# Google sign-in

```
Authorizer  {{resources.authorizer.authorizer_id}}
API         {{resources.authorizer.api_id}}
Region      {{resources.authorizer.region}}
Client ID   {{params.google_client_id}}
```

There are no alarms here. An authorizer emits no metrics — it is configuration the gateway
consults. Rejected callers are visible on the API this is attached to.

---

## Which number is it

This is the first thing to establish, because the two failures have nothing to do with each
other.

**401** — the door. The token is missing, expired, or not genuine for this application. Your
endpoint never ran.

**403 with a message about domains** — the door opened. The account signed in successfully and
is not from a domain on the list. Your endpoint ran and refused.

```bash
curl -i -s {{dependencies.api.url}} | head -1
curl -i -s -H "Authorization: Bearer $TOKEN" {{dependencies.api.url}} | head -1
```

---

## Everyone is getting 401

**Was this only just connected?** Then it is working. Callers who were fine a minute ago now
need to sign in, and nobody told them.

**Check the endpoint is asking for the right door:**

```bash
aws apigatewayv2 get-routes --api-id {{resources.authorizer.api_id}} \
  --region {{resources.authorizer.region}} \
  --query 'Items[*].[RouteKey,AuthorizationType,AuthorizerId]' --output table
```

Routes wanting sign-in show `JWT` and an `AuthorizerId` matching
`{{resources.authorizer.authorizer_id}}`. A different ID means the endpoint is connected to
another door.

**Check what this door expects:**

```bash
aws apigatewayv2 get-authorizer \
  --api-id {{resources.authorizer.api_id}} \
  --authorizer-id {{resources.authorizer.authorizer_id}} \
  --region {{resources.authorizer.region}} \
  --query '[Name,JwtConfiguration,IdentitySource]'
```

The audience must be `{{params.google_client_id}}`. A token issued for a *different* OAuth
client is perfectly genuine and will still be refused — this is the most common cause when
sign-in works in one application and not another.

**Check the token itself.** Its middle section is readable without any key:

```bash
echo "$TOKEN" | cut -d. -f2 | base64 -d 2>/dev/null | python3 -m json.tool
```

- `aud` must equal the client ID above.
- `iss` must be `https://accounts.google.com`.
- `exp` in the past means expired — the caller needs to refresh, not you.

**One more, easily missed:** this must be an **ID token**, not an access token. Google issues
both and they look similar. An access token has no `aud` matching your client and will always be
refused.

---

## Someone legitimate is getting 403

Sign-in worked. Their account is not from an allowed domain.

Currently allowed: `{{params.allowed_domains}}`

```bash
# What domain is the account actually from
echo "$TOKEN" | cut -d. -f2 | base64 -d 2>/dev/null | python3 -c "import json,sys;d=json.load(sys.stdin);print(d.get('hd','<personal account, no domain>'))"
```

No `hd` at all means a personal Google account rather than a Workspace one. There is no domain
to allow — they need an account on your organization.

To add a domain, change `allowed_domains` here and redeploy. It reaches **every endpoint**
connected to this door, so check what else is attached before widening it:

```bash
aws apigatewayv2 get-routes --api-id {{resources.authorizer.api_id}} \
  --region {{resources.authorizer.region}} \
  --query "Items[?AuthorizerId=='{{resources.authorizer.authorizer_id}}'].RouteKey" --output text
```

---

## Opening an endpoint back up

Disconnect this from that endpoint on the canvas and redeploy the endpoint. Its route goes back
to open.

Do not detach the authorizer by hand in AWS — the endpoint's next deployment would put it back,
and in the meantime the canvas would be telling everyone something untrue.

---

## Rotating the Google client

Change `google_client_id` here and redeploy. Every connected endpoint starts requiring tokens
from the new client immediately, and tokens from the old one begin failing at once — there is no
overlap where both work. Move callers first.
