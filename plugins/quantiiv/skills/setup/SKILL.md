---
name: setup
description: This skill should be used when the user asks to "set up Quantiiv", "configure Quantiiv", "install Quantiiv SDK", "initialize Quantiiv", "connect to Quantiiv", "add Quantiiv API key", "get started with Quantiiv", or mentions needing to configure QUANTIIV_API_KEY or Quantiiv credentials. Guides through SDK installation and credential configuration.
allowed-tools: Bash
argument-hint: (no arguments needed)
---

# Quantiiv Setup

Configure the Quantiiv API key, fetch a temporary registry token from the private GCS registry, install the `@quantiiv-ai/sdk`, and verify the connection.

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

The SDK is hosted on a private GCS npm registry. Installation requires two steps:

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

3. **Verify the installation**:

```bash
node -e "const { QuantiivClient } = require('@quantiiv-ai/sdk'); console.log('SDK installed successfully');"
```

If the registry token fetch fails, check that the API key is valid and not expired.

## Step 4: Verify Connection

Since the env vars written to `settings.json` are not available until the next Claude Code session, pass the values directly in the verification script:

```bash
QUANTIIV_API_KEY="<collected-key>" node -e '
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

## Requirements

- Do not store credentials in project files or `.env` files — use Claude Code settings only
- Never log or display the API key value to the user after configuration
- The registry token is temporary — if the SDK needs reinstalling later, fetch a new token first
- If the SDK is already installed, skip to Step 2
- If env vars are already configured, skip to Step 4 and verify
