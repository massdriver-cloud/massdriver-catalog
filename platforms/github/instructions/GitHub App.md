# GitHub App

The right long-term answer. Its tokens are short-lived, it is not tied to a person, and you can
revoke it in one click.

1. **Settings → Developer settings → GitHub Apps → New GitHub App**.
2. Give it these repository permissions, all **Read and write**:

   | Permission | What stops working without it |
   | --- | --- |
   | Administration | The repository is never created |
   | Contents | Starter files cannot be written |
   | Workflows | The build file cannot be written — `.github/workflows/` needs this as well as Contents |
   | Secrets | The pipeline has no credentials |
   | Variables | The pipeline does not know which registry to push to |
3. Create it, note the **App ID**, and generate a **private key**. A `.pem` downloads.
4. **Install** it on your organization, and choose **All repositories**.
5. The installation URL ends in a number — that is the **Installation ID**.

Load it with the CLI. The private key is a PEM with real newlines, and the web form corrupts
those:

```bash
mass resource create -t github-credentials -n "GitHub" -f - <<JSON
{
  "owner": "YOUR_ORG",
  "app_id": "123456",
  "app_installation_id": "78901234",
  "app_private_key": $(python3 -c 'import json,sys;print(json.dumps(open(sys.argv[1]).read()))' ~/Downloads/app.private-key.pem)
}
JSON
```

Then grant `resource:export` on it and set it as an environment default.

> [!IMPORTANT]
> Install on **all repositories**, not selected ones. A token scoped to selected repositories
> cannot touch a repository it just created, and the follow-on file and secret writes fail with a
> 404 that reads like a permissions problem and is really a selection problem.

> [!IMPORTANT]
> Adding a permission to an App does nothing until the installation accepts it. Go to
> **Settings → GitHub Apps → your app → Review request** and approve. Until you do, the App keeps
> the permissions it had, and the failure is a `403 Resource not accessible by integration` on
> exactly the calls the new permission was meant to allow.
