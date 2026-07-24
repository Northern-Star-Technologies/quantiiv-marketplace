---
name: setup
description: This skill should be used when the user asks to "set up Quantiiv", "configure Quantiiv", "install Quantiiv SDK", "initialize Quantiiv", "connect to Quantiiv", "add Quantiiv API key", "get started with Quantiiv", "update the Quantiiv SDK", "upgrade the Quantiiv SDK", or mentions needing to configure QUANTIIV_API_KEY or Quantiiv credentials, or when an installed SDK is outdated (a documented SDK method is missing at runtime). Guides through SDK installation, credential configuration, and SDK updates.
allowed-tools: Bash
argument-hint: (no arguments needed)
---

# Quantiiv Setup

Configure the Quantiiv API key, fetch a temporary registry token from Quantiiv's private package registry, install the `@quantiiv-ai/sdk`, and verify the connection.

## Step 1: Collect API Key

Prompt the user for their Quantiiv API key. Do not assume or guess this value. The API key is used both for SDK authentication and for accessing the private npm registry.

## Step 2: Configure Environment Variable

Configure the API key in Claude Code settings by adding to `~/.claude/settings.json` under the `env` key:

```json
{
  "env": {
    "QUANTIIV_API_KEY": "<user-provided-key>"
  }
}
```

Read the existing `~/.claude/settings.json` first, merge the new env vars with any existing ones, and write back. If the file does not exist, create it with just the env block.

## Step 3: Install the SDK

The SDK is hosted on Quantiiv's private npm registry. Installation requires two steps:

1. **Fetch a temporary registry token** using the API key collected in Step 1:

```bash
# Ensure ~/.npmrc ends with a newline before appending (prevents concatenation with existing last line)
[ -f ~/.npmrc ] && [ -n "$(tail -c 1 ~/.npmrc)" ] && echo '' >> ~/.npmrc
curl -s -X POST https://quantiiv-api-400709292651.us-central1.run.app/sdk/registry-token \
  -H "Authorization: Bearer <collected-key>" | jq -r '.npmrcSnippet' >> ~/.npmrc
```

2. **Install the SDK globally**:

```bash
npm install -g @quantiiv-ai/sdk
```

3. **Verify the installation** (use `NODE_PATH` to resolve global modules):

```bash
NODE_PATH="$(npm root -g)" node -e "const { QuantiivClient } = require('@quantiiv-ai/sdk'); console.log('SDK installed successfully');"
```

If the registry token fetch fails, check that the API key is valid and not expired.

## Step 4: Verify Connection

Since the env vars written to `settings.json` are not available until the next Claude Code session, pass the values directly in the verification script:

```bash
QUANTIIV_API_KEY="<collected-key>" NODE_PATH="$(npm root -g)" node -e '
const { QuantiivClient } = require("@quantiiv-ai/sdk");
const client = new QuantiivClient({
  token: process.env.QUANTIIV_API_KEY,
});
(async () => {
  try {
    const result = await client.companies.list({ limit: 1 });
    console.log("Connected successfully. Found " + result.data.length + " company(ies).");
  } catch (err) {
    console.error("Connection failed:", err.message);
  }
})();
'
```

After setup completes, inform the user that the env vars will be available automatically in future Claude Code sessions. The current session requires a restart for env vars to take effect.

If verification fails:
- Check that the API key is valid and not expired
- Ensure no proxy or firewall is blocking the connection

## Updating the SDK

Use this flow when the user asks to update/upgrade the SDK, or when the
installed SDK is outdated — e.g. a documented method (such as
`client.fiscalCalendar` or `client.companies.getReportingFreshnessContext`)
is `undefined` at runtime.

The API key is already stored in the session as `$QUANTIIV_API_KEY`
(configured during setup) — do **not** ask the user for it again. If the
variable is empty (`[ -z "$QUANTIIV_API_KEY" ]`), run the full setup above
first.

1. **Fetch a fresh registry token** — registry tokens are temporary, so the
   one from install time has likely expired. Always refresh it before any
   npm operation on the SDK:

```bash
# Ensure ~/.npmrc ends with a newline before appending (prevents concatenation with existing last line)
[ -f ~/.npmrc ] && [ -n "$(tail -c 1 ~/.npmrc)" ] && echo '' >> ~/.npmrc
curl -s -X POST https://quantiiv-api-400709292651.us-central1.run.app/sdk/registry-token \
  -H "Authorization: Bearer $QUANTIIV_API_KEY" | jq -r '.npmrcSnippet' >> ~/.npmrc
```

2. **Update the package**:

```bash
npm install -g @quantiiv-ai/sdk@latest
```

3. **Verify the new version loads**:

```bash
NODE_PATH="$(npm root -g)" node -e "console.log('SDK version:', require('@quantiiv-ai/sdk/package.json').version)"
```

If the token fetch returns an error, or the npm install fails with 401/403,
the stored API key may be invalid or expired — re-run the full setup to
collect a fresh key.

## Requirements

- Do not store credentials in project files or `.env` files — use Claude Code settings only
- Never log or display the API key value to the user after configuration
- The registry token is temporary — before any later npm install/update of the SDK, fetch a new token first (see "Updating the SDK")
- For updates, reuse `$QUANTIIV_API_KEY` from the session environment — never re-prompt the user for a key they already configured
- If the SDK is already installed, skip to Step 2
- If env vars are already configured, skip to Step 4 and verify
