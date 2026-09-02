# Personal Access Token

The fast path. Use this to get moving; move to a GitHub App before anyone else depends on it.

1. Go to **Settings → Developer settings → Personal access tokens → Tokens (classic)** and choose
   **Generate new token (classic)**.
2. Tick **`repo`** and **`admin:org`**. Nothing else is needed.
3. Set an expiry you will actually remember. This token can create and delete repositories in your
   organization.
4. Copy it — GitHub shows it once.

Load it with the CLI:

```bash
mass resource create -t github-credentials -n "GitHub" -f - <<JSON
{ "owner": "YOUR_ORG", "token": "ghp_..." }
JSON
```

Then share it: grant `resource:export` on the resource, and set it as an environment default so
components pick it up without anyone choosing a credential.

> [!IMPORTANT]
> This token carries one person's access. When they leave, every repository the platform manages
> stops working. That is the reason to move to an App.
