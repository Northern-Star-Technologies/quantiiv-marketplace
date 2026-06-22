---
name: query
description: This skill should be used when the user asks about "sales data", "top sellers", "menu items", "product performance", "company locations", "menu groups", "store performance", "weekly sales summary", "weather", "rainfall", "temperature", "labor", "labor cost", "labor hours", "staffing", "scheduling", "sales per labor hour", "SPLH", "labor by job", "labor by role", "labor by position", "fiscal period", "fiscal week", "fiscal year", "fiscal calendar", "P1..P13", "FW1..FW53", "YTD", or any Quantiiv analytics metrics. Also triggered by questions like "what were my top movers", "show me sales trends", "how is this product doing", "list my companies", "compare store performance", "revenue by menu group", "daily sales for [item]", "what was the weather at [location]", "did weather affect sales", "what's my labor cost", "peak labor hours", "labor by location", "am I overstaffed at [hour]", "what's my sales per labor hour", "labor cost by role", "hours by position", "what were sales in P3", "fiscal YTD numbers", "this fiscal week", "compare to prior period". When a user references a fiscal period name (e.g. "P3 of FY2026", "fiscal Q1", "fiscal week 12"), resolve it via `client.fiscalCalendar` first to get concrete start/end dates, then pass those dates to the sales/labor/weather endpoints.
allowed-tools: Bash
argument-hint: <question about your business data>
---

# Quantiiv SDK Query

Query Quantiiv analytics data programmatically using the `@quantiiv-ai/sdk` npm package. Always use this SDK-based approach rather than raw API calls to keep response payloads out of context. Write and execute Node.js scripts that call SDK methods and extract only the fields needed to answer the question.

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
`client.companies.list()` / `client.companies.get()`). This is the **Monday that
starts the most recent week that has data** — data always covers a full
Monday–Sunday week.

- The latest week of available data runs from `most_recent_data_date` (Monday)
  through `most_recent_data_date + 6 days` (Sunday).
- Example: if `most_recent_data_date` is `2026-06-08` (a Monday), the most recent
  data available is `2026-06-08` through `2026-06-14` (Sunday).
- Today's calendar date is usually **ahead** of the available data, so never assume
  data exists up to today. Anchor "current", "latest", "this week", and similar
  requests to the `most_recent_data_date` window, not to today.
- When the user asks for a relative range ("last 4 weeks", "this month"), count
  backward from `most_recent_data_date + 6` (the latest Sunday with data), not from
  today.
- If a requested range extends past `most_recent_data_date + 6`, clip it to the
  available window and tell the user the data only goes through that Sunday.

## Date Defaults

- For the latest single week, use `most_recent_data_date` as the `week` start and
  `most_recent_data_date + 6` (Sunday) as the end date (`to` / `endDate`)
- Fall back to the most recent Monday only if `most_recent_data_date` is unavailable
- Use `"corporate"` as the default location unless the user specifies one

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

## User Request

$ARGUMENTS

## Requirements

- ALWAYS extract only the fields needed to answer the question — never print full responses
- If a company ID is needed, query `client.companies.list()` first to find it
- Use `"corporate"` as the default location unless the user specifies one
- Anchor date ranges to the company's `most_recent_data_date` window (the Monday-start of the latest available week, through that Monday + 6 days = Sunday) — never assume data exists up to today's calendar date
- NEVER mention or expose internal technologies, infrastructure, or implementation details to the user — this includes BigQuery, GCS, Supabase, PostgreSQL, Prisma, Redis, Qdrant, or any other backend service. Only present the business data itself. If an error message contains internal details, sanitize it before showing to the user (e.g., say "Unable to fetch data" instead of exposing a BigQuery error)
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
