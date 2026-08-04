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

**Complete setup entirely in this conversation.** The user is not expected to
open a terminal, edit a file, or run anything themselves. They paste their API
key into the chat and you do the rest. Never tell them to run a command in their
own terminal, and never make finishing setup contingent on something outside
this chat.

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

- `key_in_env: yes` or `key_in_settings: yes` → a key is already configured. Skip
  to **Step 3** (install) or **Step 4** (verify). Do **not** ask for a key again.
- Otherwise → **Step 2**.
- `settings_writable: no` → this environment has no durable settings file; use
  the session-only path in **Step 2a** so setup still finishes in chat.

## Step 2: Ask for the API key and save it

Ask the user to paste their Quantiiv API key into the chat. Do not guess or
assume the value. A short prompt is enough, e.g. "Paste your Quantiiv API key and
I'll finish the setup."

Then save it with this command, substituting the pasted key on the line between
the two `__QUANTIIV_KEY_EOF__` markers:

```bash
node -e '
const fs = require("fs"), os = require("os"), path = require("path");
const key = fs.readFileSync(0, "utf8").trim();
if (!key) { console.error("No key received"); process.exit(1); }
const p = path.join(os.homedir(), ".claude", "settings.json");
fs.mkdirSync(path.dirname(p), { recursive: true });
let cfg = {};
try { cfg = JSON.parse(fs.readFileSync(p, "utf8")) || {}; } catch (e) {}
cfg.env = cfg.env || {};
cfg.env.QUANTIIV_API_KEY = key;
fs.writeFileSync(p, JSON.stringify(cfg, null, 2) + "\n");
console.log("Saved QUANTIIV_API_KEY to " + p + " (" + key.length + " chars)");
' <<'__QUANTIIV_KEY_EOF__'
<paste the key here, on its own line>
__QUANTIIV_KEY_EOF__
```

Why this shape:

- The key arrives on **stdin via the heredoc**, so it never lands in `argv` and
  never shows up in the process list.
- The quoted `<<'__QUANTIIV_KEY_EOF__'` delimiter means the shell does not expand
  the contents — keys containing `$`, backticks, quotes, or spaces are safe.
- It **merges** into any existing `~/.claude/settings.json` (other `env` entries
  and settings are preserved), and creates the file and directory if absent.

Confirm the `Saved QUANTIIV_API_KEY to ...` output, then continue to Step 3.
Write the key exactly once — every later step reads it back from
`settings.json`, so never paste it into another command and never print it back
to the user.

### Step 2a: Environments with no durable settings file

If Step 1 reported `settings_writable: no`, `~/.claude/settings.json` will not
survive, so store the key for this session only — still without leaving the
chat:

```bash
umask 077
node -e '
const fs = require("fs"), os = require("os"), path = require("path");
const key = fs.readFileSync(0, "utf8").trim();
if (!key) { console.error("No key received"); process.exit(1); }
const p = path.join(os.tmpdir(), ".quantiiv-session-key");
fs.writeFileSync(p, key, { mode: 0o600 });
console.log("Stored key for this session at " + p);
' <<'__QUANTIIV_KEY_EOF__'
<paste the key here, on its own line>
__QUANTIIV_KEY_EOF__
```

Every later step already falls back to this file (see the `read the key` snippet
below). Tell the user setup is good for this session and that it will need to be
redone next time, since this environment does not keep settings — do not ask them
to fix that themselves.

### Reading the key back

Steps 3 and 4 need the key without re-asking for it. This resolves it from the
environment, then `settings.json`, then the session file, and prints nothing:

```bash
QKEY="${QUANTIIV_API_KEY:-$(node -e '
const fs = require("fs"), os = require("os"), path = require("path");
let k = "";
try { k = (JSON.parse(fs.readFileSync(path.join(os.homedir(), ".claude", "settings.json"), "utf8")).env || {}).QUANTIIV_API_KEY || ""; } catch (e) {}
if (!k) { try { k = fs.readFileSync(path.join(os.tmpdir(), ".quantiiv-session-key"), "utf8").trim(); } catch (e) {} }
process.stdout.write(k);
')}"
```

Prepend it to the commands below that need `$QKEY`. Never `echo` it.

## Step 3: Install the SDK

The SDK is on Quantiiv's private npm registry, so installing needs a temporary
registry token first.

1. **Fetch a registry token.** The block is delimited so repeat runs replace it
   instead of appending duplicate registry lines to `~/.npmrc`:

```bash
QKEY="${QUANTIIV_API_KEY:-$(node -e '
const fs = require("fs"), os = require("os"), path = require("path");
let k = "";
try { k = (JSON.parse(fs.readFileSync(path.join(os.homedir(), ".claude", "settings.json"), "utf8")).env || {}).QUANTIIV_API_KEY || ""; } catch (e) {}
if (!k) { try { k = fs.readFileSync(path.join(os.tmpdir(), ".quantiiv-session-key"), "utf8").trim(); } catch (e) {} }
process.stdout.write(k);
')}"
[ -z "$QKEY" ] && echo "No API key found — do Step 2 first" && exit 1
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
echo "registry configured"
```

2. **Install globally**:

```bash
npm install -g @quantiiv-ai/sdk
```

3. **Verify the package loads** (`NODE_PATH` resolves global modules):

```bash
NODE_PATH="$(npm root -g)" node -e "const { QuantiivClient } = require('@quantiiv-ai/sdk'); console.log('SDK installed successfully');"
```

If the token fetch fails, the key is likely invalid or expired — ask the user to
paste a fresh one and redo Step 2. Never print the token or the key while
debugging.

## Step 4: Verify the connection

Env vars from `settings.json` are not in the current session yet, so resolve the
key into this one command's environment. It never prints the key:

```bash
QUANTIIV_API_KEY="${QUANTIIV_API_KEY:-$(node -e '
const fs = require("fs"), os = require("os"), path = require("path");
let k = "";
try { k = (JSON.parse(fs.readFileSync(path.join(os.homedir(), ".claude", "settings.json"), "utf8")).env || {}).QUANTIIV_API_KEY || ""; } catch (e) {}
if (!k) { try { k = fs.readFileSync(path.join(os.tmpdir(), ".quantiiv-session-key"), "utf8").trim(); } catch (e) {} }
process.stdout.write(k);
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

On success, tell the user setup is complete and they can start asking questions
right away. The key loads automatically from `settings.json` in future sessions;
until this session restarts, `$QUANTIIV_API_KEY` may be empty in the environment,
so keep prepending the resolver above to SDK commands rather than asking the user
to restart or re-enter anything.

If verification fails:

- The key may be invalid or expired — ask for a fresh one and redo Step 2
- A proxy or firewall may be blocking the connection

## Updating the SDK

Use this when the user asks to update/upgrade the SDK, or when the installed SDK
is outdated — e.g. a documented method (such as `client.fiscalCalendar` or
`client.companies.getReportingFreshnessContext`) is `undefined` at runtime.

The key is already stored — do **not** ask for it again. Only if the resolver
above returns empty should you run the full setup.

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
be invalid or expired — ask the user to paste a fresh one and redo Step 2.

## Requirements

- Everything happens in this conversation. Never instruct the user to open a
  terminal, run a command themselves, or hand-edit a file
- Accept the key pasted into the chat, and write it **exactly once** using the
  Step 2 heredoc. Never re-paste it into another command, never `echo` it, and
  never repeat it back to the user — later steps use the resolver instead
- Never log or display the key or the registry token, not even partially, and not
  while debugging a failure
- Do not store credentials in project files or `.env` files — Claude Code
  settings, or the session file from Step 2a when settings are not writable
- Check Step 1 before asking for anything; if a key is already configured, skip
  straight to install/verify
- The registry token is temporary — refresh it before any later npm
  install/update of the SDK (see "Updating the SDK")
- Merge into `~/.claude/settings.json`; never overwrite it wholesale
- If the SDK is installed and a key is configured, go straight to Step 4
