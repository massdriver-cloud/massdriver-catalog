# Register a Fivetran Account

## Get the agent token

1. Open the Fivetran dashboard.
2. Create a hybrid deployment agent.
3. Copy the token. Fivetran shows it one time only.

## Get the API key and the secret

1. Open the account settings.
2. Create an API key.
3. Copy the key and the secret.

## Values

| Field | Where it comes from |
|---|---|
| `agent_token` | The token of the agent. |
| `group_id` | The destination group that receives the data. |
| `api_key` | The API key of the account. |
| `api_secret` | The secret of that key. |

## Warning

The agent token joins an agent to your account. Anybody who holds it can send
data into your destination. Massdriver masks the field, and it records every
download.
