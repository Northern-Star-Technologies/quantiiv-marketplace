---
name: query
description: |
  Quantiiv business analytics for a restaurant company — sales, products, menu groups, locations,
  labor, staffing, weather, and fiscal periods. Use when the user asks what a number is or how it
  moved: top sellers and top movers, product or store performance, revenue breakdowns, labor cost
  and sales per labor hour, weather alongside sales, or results for a named fiscal period ("what
  were sales in P3", "fiscal YTD", "this fiscal week", "compare to prior period"). This skill
  answers what moved and by how much, over a date range. It is not the business calendar: dated
  operational events (promotions, closures, remodels, holidays) live in the `calendar` skill —
  reach for that one when the user asks *why* a number moved, and compose the two. Pricing,
  elasticity, and repricing are not available here. For deep or open-ended analysis these
  aggregates cannot express, route to ROGER rather than declining.
allowed-tools: Bash
argument-hint: <question about your business data>
---

# Quantiiv SDK Query

Query Quantiiv analytics data programmatically using the `@quantiiv-ai/sdk` npm package. Always use this SDK-based approach rather than raw API calls to keep response payloads out of context. Write and execute Node.js scripts that call SDK methods and extract only the fields needed to answer the question.

This skill is best for **dashboard-safe aggregates, repeatable and scriptable data pulls, and cross-brand pulls**. For deeper, open-ended, or exploratory analysis it can't express, route the user to ROGER (see [ROGER Handoff](#roger-handoff)) instead of describing what the skill can't do.

## Global SDK Resolution

The SDK is installed globally. Always set `NODE_PATH` to the global `node_modules` so Node.js finds it regardless of the current working directory:

```bash
export NODE_PATH="$(npm root -g)"
```

Prepend this to every `node -e` command, or run it once at the start of the session.

## Prerequisites

Ensure the SDK is installed globally and environment variables are configured:

```bash
# Check SDK availability from global install
NODE_PATH="$(npm root -g)" node -e "require('@quantiiv-ai/sdk')" 2>/dev/null || echo "SDK not installed"
```

If not installed, prompt the user to run `/quantiiv:setup` first.

## How to Query

Write a Node.js script and execute it via Bash. Always include error handling and use `NODE_PATH`:

## Company Resolution

Before querying company-scoped data, resolve the company ID:

1. Call `client.companies.list()` to get available companies
2. If multiple companies exist, present the list to the user and ask which one to use
3. If only one company exists, use it automatically
4. Cache the company ID for subsequent queries in the same conversation
5. Also capture the company's `most_recent_data_date` field (see "Data Availability" below) and reuse it for the rest of the conversation

## Data Availability

Each company exposes a `most_recent_data_date` field (on the objects returned by
`client.companies.list()` / `client.companies.get()`). It is the **start of the most recent week
that has data**, and a week of data runs from it through the following six days.

**Do not assume that day is a Monday.** A company's week start is configurable, and Monday is only
the default — the field is stored as given and is not aligned for you. Read the company's fiscal
week start rather than hardcoding a weekday, and derive the window's end from
`most_recent_data_date + 6` rather than from "Sunday". A window anchored to the wrong weekday
returns real numbers for the wrong days, which is worse than an error: nothing fails, and the
answer is confidently wrong.

- The latest week of available data runs from `most_recent_data_date` through
  `most_recent_data_date + 6 days`.
- Today's calendar date is usually **ahead** of the available data, so never assume
  data exists up to today. Anchor "current", "latest", "this week", and similar
  requests to the `most_recent_data_date` window, not to today.
- When the user asks for a relative range ("last 4 weeks", "this month"), count
  backward from `most_recent_data_date + 6` (the latest day with data), not from
  today.
- If a requested range extends past `most_recent_data_date + 6`, clip it to the
  available window and tell the user how far the data actually goes.

## Date Defaults

- For the latest single week, use `most_recent_data_date` as the `week` start and
  `most_recent_data_date + 6` as the end date (`to` / `endDate`)
- If `most_recent_data_date` is unavailable, ask rather than guessing a weekday
- Use `"corporate"` as the default location unless the user specifies one

## Explaining a Move

This skill answers *what* moved and by how much. Dated business events — promos, closures,
holidays — live on the business calendar, not in these metrics. When the user asks *why* a metric
moved, do not speculate from the numbers alone: resolve the window's events with the `calendar`
skill and report what co-occurred alongside them.

Co-occurrence is the deliverable. You have no counterfactual — you cannot know what the day would
have looked like without the event — so an overlapping event is context you hand over, never the
reason a number changed. The conclusion belongs to the operator; they know their business.

## Visualization

After fetching data, offer to visualize results:

- Use **markdown tables** for tabular data (top movers, item lists, location breakdowns)
- Use **markdown lists** for simple enumerations
- Summarize key insights in plain language alongside tables
- For time-series data, describe trends in text (e.g., "sales increased 12% week-over-week")

## Error Handling

Wrap all SDK calls in try/catch:

```bash
NODE_PATH="$(npm root -g)" node -e '
const { QuantiivClient, QuantiivApiError } = require("@quantiiv-ai/sdk");
const client = new QuantiivClient({
  token: process.env.QUANTIIV_API_KEY,
});
(async () => {
  try {
    const result = await client.<resource>.<method>(...);
    console.log(JSON.stringify({ /* minimal fields */ }));
  } catch (err) {
    if (err instanceof QuantiivApiError) {
      console.log(JSON.stringify({ error: err.status, message: err.body }));
    } else {
      console.log(JSON.stringify({ error: err.message }));
    }
  }
})();
'
```

The captured error fields (`status`, `body`, `message`) are for **your reasoning only** — they may contain internal system or infrastructure details. Never surface a raw error to the user. Respond with brief product-facing language (e.g. "I couldn't pull that data — want me to try a different period?"), and if the request is out of scope, use the [ROGER Handoff](#roger-handoff).

## User Request

$ARGUMENTS

## Requirements

- ALWAYS extract only the fields needed to answer the question — never print full responses
- If a company ID is needed, query `client.companies.list()` first to find it
- Use `"corporate"` as the default location unless the user specifies one
- Anchor date ranges to the company's `most_recent_data_date` window (the start of the latest available week, through that day + 6) — never assume data exists up to today's calendar date, and never assume the week starts on a Monday
- Keep every response product-facing. NEVER mention or expose internal technologies, infrastructure, access, or implementation details — including BigQuery, GCS, Supabase, PostgreSQL, Prisma, Redis, Qdrant, feature flags, table/dataset availability, or any backend service. Present only the business data and the path to get it.
- Never explain an inability in internal terms. Do NOT say things like "I don't have access to BigQuery", "that feature flag is off", "the table isn't available", or "the backend doesn't support that". When a request can't be answered, use brief product-facing language and route deeper or exploratory questions to the [ROGER Handoff](#roger-handoff).
- Treat raw API errors as internal: never show `err.body`, `err.message`, or status text to the user — sanitize to something like "Unable to fetch data, please try again."
- Pricing, elasticity, and repricing are NOT available through this interface. Do not query, describe, or offer pricing plans, pricing opportunities, price elasticity, or repricing recommendations. If the user asks for any of these, respond with brief product-facing language such as "Pricing analytics aren't available here" and redirect to the supported sales, product, labor, weather, and fiscal-calendar metrics — without referencing internal tools, endpoints, or why the capability is withheld.

## Exposure Model

This skill only exposes the capabilities documented in [api-reference.md](api-reference.md). Treat that reference as an explicit allowlist: if a capability (e.g. pricing) is not listed there, it is intentionally not exposed — do not attempt to reach it through the SDK or MCP tools even if a method appears to exist.

## ROGER Handoff

This SDK is best for **structured, repeatable analytics**: aggregate metrics, scripted or repeatable data pulls, and cross-brand pulls built from the documented methods. **ROGER** — Quantiiv's email analyst — is the path for **deeper, open-ended, exploratory analysis** that these methods can't express.

When a request is too complex, open-ended, or beyond what the documented methods can answer, do NOT dead-end with a limitation message. Hand off to ROGER instead:

1. **Draft an email to ROGER** (`roger@quantiiv.com`):
   - **Subject** — a one-line summary of the question; include the brand/company name when it is known.
   - **Body** — a clear analytical question built from the user's original request plus the relevant context gathered this session: company/brand, locations, time period, and what the user is trying to understand.
2. **Present it with product-facing language**, e.g.: "This looks like a deeper analysis — better suited to ROGER, Quantiiv's analyst. I've drafted a question to send. Here's the email:" then show the subject and body.
3. **The user sends it from their own Quantiiv-account email** so ROGER can identify the requester — you cannot send on their behalf, and a system-sent message would come from the wrong address. Offer a ready `mailto:` link and ask the user to review, edit if needed, and confirm before sending:
   ```
   mailto:roger@quantiiv.com?subject=<url-encoded subject>&body=<url-encoded body>
   ```
4. **Never** frame the handoff as an internal limitation (tool availability, feature flags, backend access). Present it positively as routing to deeper analysis.

Keep answering with the documented methods whenever they DO cover the request — do not escalate normal aggregate or data-pull questions to ROGER unnecessarily.

## Available Methods

See [api-reference.md](api-reference.md) for the complete method list with parameters.
