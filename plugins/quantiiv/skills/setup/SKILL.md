---
name: setup
description: This skill should be used when the user asks to "set up Quantiiv", "configure Quantiiv", "install Quantiiv SDK", "initialize Quantiiv", "connect to Quantiiv", "add Quantiiv API key", "get started with Quantiiv", "update the Quantiiv SDK", "upgrade the Quantiiv SDK", or mentions needing to configure QUANTIIV_API_KEY or Quantiiv credentials, or when an installed SDK is outdated (a documented SDK method is missing at runtime). Guides through SDK installation, credential configuration, and SDK updates.
allowed-tools: Bash
argument-hint: (no arguments needed)
---

# Quantiiv Setup

Configure the Quantiiv API key, fetch a temporary registry token from Quantiiv's
private package registry, install the `@quantiiv-ai/sdk`, and verify the
connection.

**Never ask the user to paste their API key into the conversation, and never
put the key literal into a command you run.** The key must go from the user
straight into storage without passing through the transcript — Step 2 gives them
a command that does exactly that. Handling a pasted key would both expose it in
the conversation history (forcing a rotation) and stall this flow.

## Step 1: Check what already exists

Run this first, every time. It decides which steps are needed and prints no
secret values:

```bash
echo "key_in_env: $([ -n "${QUANTIIV_API_KEY:-}" ] && echo yes || echo no)"
echo "key_in_settings: $([ -f "$HOME/.claude/settings.json" ] && grep -q QUANTIIV_API_KEY "$HOME/.claude/settings.json" && echo yes || echo no)"
if [ -d "$HOME/.claude" ]; then
  echo "settings_writable: $([ -w "$HOME/.claude" ] && echo yes || echo no)"
else
  echo "settings_writable: $([ -w "$HOME" ] && echo yes || echo no)"   # dir is created on first write
fi
echo "sdk_installed: $(NODE_PATH="$(npm root -g)" node -e "require('@quantiiv-ai/sdk')" 2>/dev/null && echo yes || echo no)"
```

Then branch:

- `key_in_env: yes` → the key is already configured. Skip to **Step 3** (install)
  or **Step 4** (verify) — do not collect a key again.
- `key_in_settings: yes` but `key_in_env: no` → the key is saved but this session
  started before it was written. Tell the user to restart Claude Code; meanwhile
  Step 4's verification still works.
- `settings_writable: no` → this environment cannot persist credentials. Go to
  **Step 2b**.

## Step 2: Save the API key (user-run, never through chat)

Give the user this command to run **in their own terminal**. It prompts silently,
writes straight into their Claude Code settings, and never echoes the key or
places it in the conversation:

```bash
printf 'Quantiiv API key: '; read -rs QKEY; echo; QKEY="$QKEY" python3 -c '
import json, os
p = os.path.expanduser("~/.claude/settings.json")
os.makedirs(os.path.dirname(p), exist_ok=True)
try:
    with open(p) as f: cfg = json.load(f)
except (FileNotFoundError, ValueError):
    cfg = {}
cfg.setdefault("env", {})["QUANTIIV_API_KEY"] = os.environ["QKEY"]
with open(p, "w") as f: json.dump(cfg, f, indent=2)
print("Saved QUANTIIV_API_KEY to", p)
' ; unset QKEY
```

It merges into any existing `settings.json` rather than overwriting, and passes
the key via the environment (not `argv`) so it never appears in the process list.

Ask the user to confirm they saw `Saved QUANTIIV_API_KEY to ...`, then continue.
The key will not be in *this* session's environment yet — Step 3 and Step 4 read
it back from `settings.json`, and a restart picks it up for everything after.

### Step 2a: If the user would rather not run a command

Have them write the key to a file themselves (in their editor, or
`pbpaste > ~/.quantiiv-key`), tell you the path, then run:

```bash
QKEY="$(cat <path>)" python3 -c '
import json, os
p = os.path.expanduser("~/.claude/settings.json")
os.makedirs(os.path.dirname(p), exist_ok=True)
try:
    with open(p) as f: cfg = json.load(f)
except (FileNotFoundError, ValueError):
    cfg = {}
cfg.setdefault("env", {})["QUANTIIV_API_KEY"] = os.environ["QKEY"]
with open(p, "w") as f: json.dump(cfg, f, indent=2)
print("Saved QUANTIIV_API_KEY to", p)
' && rm -f <path> && echo "temp key file removed"
```

Never `cat` the file to the transcript — read it only into the variable above,
and delete it when done.

### Step 2b: Environments that cannot persist credentials

Some surfaces (sandboxed or scratch workspaces, ephemeral cloud sessions) have
no durable `~/.claude/settings.json`, so a saved key would vanish. Say so plainly
and up front — before asking for anything — and offer:

1. **Recommended** — run `/quantiiv:setup` in Claude Code on their own machine
   (desktop app or terminal), where the key persists across sessions.
2. **Session-only** — if they just need one query now, they can export the key in
   the shell that launches the session:
   `export QUANTIIV_API_KEY=...` (their own terminal, not through chat). It
   works until the session ends.

Do not attempt to write `settings.json` in an environment where Step 1 reported
`settings_writable: no`.

## Step 3: Install the SDK

The SDK is on Quantiiv's private npm registry, so installing needs a temporary
registry token first.

1. **Fetch a registry token.** The block is delimited so repeat runs replace it
   instead of appending duplicate registry lines to `~/.npmrc`:

```bash
QKEY="${QUANTIIV_API_KEY:-$(python3 -c '
import json, os
p = os.path.expanduser("~/.claude/settings.json")
try:
    with open(p) as f: print(json.load(f).get("env", {}).get("QUANTIIV_API_KEY", ""))
except Exception: print("")
')}"
[ -z "$QKEY" ] && echo "No API key found — complete Step 2 first" && exit 1
if [ -f ~/.npmrc ]; then
  awk '/# >>> quantiiv sdk registry >>>/{s=1} s==0{print} /# <<< quantiiv sdk registry <<</{s=0}' \
    ~/.npmrc > ~/.npmrc.new && mv ~/.npmrc.new ~/.npmrc
fi
{
  echo '# >>> quantiiv sdk registry >>>'
  curl -s -X POST https://quantiiv-api-400709292651.us-central1.run.app/sdk/registry-token \
    -H "Authorization: Bearer $QKEY" | jq -r '.npmrcSnippet'
  echo '# <<< quantiiv sdk registry <<<'
} >> ~/.npmrc
unset QKEY
grep -c '' ~/.npmrc >/dev/null && echo "registry configured"
```

2. **Install globally**:

```bash
npm install -g @quantiiv-ai/sdk
```

3. **Verify the package loads** (`NODE_PATH` resolves global modules):

```bash
NODE_PATH="$(npm root -g)" node -e "const { QuantiivClient } = require('@quantiiv-ai/sdk'); console.log('SDK installed successfully');"
```

If the token fetch fails, the API key is likely invalid or expired — have the
user re-run Step 2 with a fresh key. Never print the token or the key while
debugging.

## Step 4: Verify the connection

Env vars from `settings.json` are not in the current session until it restarts,
so read the key back into a single command's environment. This never prints it:

```bash
QUANTIIV_API_KEY="${QUANTIIV_API_KEY:-$(python3 -c '
import json, os
p = os.path.expanduser("~/.claude/settings.json")
try:
    with open(p) as f: print(json.load(f).get("env", {}).get("QUANTIIV_API_KEY", ""))
except Exception: print("")
')}" NODE_PATH="$(npm root -g)" node -e '
const { QuantiivClient } = require("@quantiiv-ai/sdk");
const client = new QuantiivClient({ token: process.env.QUANTIIV_API_KEY });
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

On success, tell the user setup is complete and that the key loads automatically
in future sessions — this session needs a restart for `$QUANTIIV_API_KEY` to be
present everywhere.

If verification fails:

- The API key may be invalid or expired — re-run Step 2 with a fresh key
- A proxy or firewall may be blocking the connection

## Updating the SDK

Use this when the user asks to update/upgrade the SDK, or when the installed SDK
is outdated — e.g. a documented method (such as `client.fiscalCalendar` or
`client.companies.getReportingFreshnessContext`) is `undefined` at runtime.

The key is already stored — do **not** ask the user for it again. If both
`$QUANTIIV_API_KEY` and the `settings.json` entry are empty, run the full setup
above first.

1. **Refresh the registry token** — tokens are temporary, so the one from install
   time has likely expired. Re-run the token step from **Step 3.1** (it replaces
   the delimited block rather than appending).

2. **Update the package**:

```bash
npm install -g @quantiiv-ai/sdk@latest
```

3. **Verify the new version loads**:

```bash
NODE_PATH="$(npm root -g)" node -e "console.log('SDK version:', require('@quantiiv-ai/sdk/package.json').version)"
```

If the token fetch errors, or npm install fails with 401/403, the stored key may
be invalid or expired — re-run Step 2 to collect a fresh one.

## Requirements

- NEVER ask the user to paste the API key into the conversation, and never
  interpolate a key literal into a command. Use the user-run command in Step 2,
  or read the value from `settings.json` into a single command's environment
- Never log, echo, or display the key or the registry token — not even
  partially, and not while debugging a failure
- Do not store credentials in project files or `.env` files — Claude Code
  settings only
- Check Step 1 before collecting anything; if the key is already in the
  environment or in `settings.json`, skip straight to install/verify
- If the environment cannot persist credentials (`settings_writable: no`), say so
  before asking for a key and route the user per Step 2b — do not half-complete
  a setup that will be wiped
- The registry token is temporary — refresh it before any later npm
  install/update of the SDK (see "Updating the SDK")
- Merge into `~/.claude/settings.json`; never overwrite it wholesale
- If the SDK is already installed and the key is configured, skip to Step 4
