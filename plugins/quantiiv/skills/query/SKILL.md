---
name: query
description: This skill should be used when the user asks about "sales data", "top sellers", "menu items", "product performance", "company locations", "menu groups", "store performance", "weekly sales summary", "weather", "rainfall", "temperature", "labor", "labor cost", "labor hours", "staffing", "scheduling", "sales per labor hour", "SPLH", "labor by job", "labor by role", "labor by position", "fiscal period", "fiscal week", "fiscal year", "fiscal calendar", "P1..P13", "FW1..FW53", "YTD", or any Quantiiv analytics metrics. Also triggered by questions like "what were my top movers", "show me sales trends", "how is this product doing", "list my companies", "compare store performance", "revenue by menu group", "daily sales for [item]", "what was the weather at [location]", "did weather affect sales", "what's my labor cost", "peak labor hours", "labor by location", "am I overstaffed at [hour]", "what's my sales per labor hour", "labor cost by role", "hours by position", "what were sales in P3", "fiscal YTD numbers", "this fiscal week", "compare to prior period". When a user references a fiscal period name (e.g. "P3 of FY2026", "fiscal Q1", "fiscal week 12"), resolve it via `client.fiscalCalendar` first to get concrete start/end dates, then pass those dates to the sales/labor/weather endpoints. For "latest"/"current" data, anchor to the daily-updated `latest_safe_data_date` from the reporting freshness context — not to the latest week start — and include the current in-progress fiscal week as week-to-date; only default to the last complete week when the user explicitly asks for a complete-week overview. For "this week"/"last week" or any weekly range, align week boundaries to the company's fiscal week start day (`calendar_config.week_start_day`, e.g. Tuesday) — never assume Monday.
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
5. Then fetch the company's reporting freshness context (see "Data Availability"
   below) and reuse it for the rest of the conversation — but always fetch it
   fresh at the start of a new session, since data loads daily

## Data Availability

After resolving the company, fetch the authoritative freshness context:

```bash
NODE_PATH="$(npm root -g)" node -e '
const { QuantiivClient } = require("@quantiiv-ai/sdk");
const client = new QuantiivClient({ token: process.env.QUANTIIV_API_KEY });
(async () => {
  try {
    const f = await client.companies.getReportingFreshnessContext("<companyId>");
    console.log(JSON.stringify({
      status: f.status,
      latest_safe_data_date: f.latest_safe_data_date,
      latest_complete_business_week: f.latest_complete_business_week,
      week_start_day: f.calendar_config?.week_start_day,
      week_end_day: f.calendar_config?.week_end_day,
      warnings: f.warnings.map((w) => w.message),
    }));
  } catch (err) {
    console.log(JSON.stringify({ error: err.message }));
  }
})();
'
```

The endpoint is scoped to the authenticated user's company and managed
locations, so a location-scoped user automatically gets their own freshness.

- `latest_safe_data_date` is the **actual data-through date**. Use it for all
  freshness language — say "data is available through YYYY-MM-DD" with this
  exact date — and as the **maximum end date** for every query.
- Keep three concepts separate:
  - `latest_safe_data_date` (freshness context) — the real sales data-through
    boundary. The only value to present as data freshness.
  - `most_recent_data_date` (company field) / `latest_complete_business_week` —
    weekly period anchors for selecting fiscal weeks. **Never** present a week
    start (or week start + 6) as the data-through date; midweek, daily data
    usually extends past the last complete week.
  - Today's calendar date — useful for interpreting relative language, but not
    proof that data has loaded.
- Data normally loads each morning through the prior calendar day, but never
  assume it: if `latest_safe_data_date` is older than yesterday, report the
  API's date honestly — do not claim data through yesterday.
- Anchor "current", "latest", "last N days", month-to-date, and relative ranges
  to `latest_safe_data_date`, not to today. If a requested range extends past
  it, clip the range to `latest_safe_data_date` and tell the user data is only
  available through that date.
- If the freshness call fails or `latest_safe_data_date` is null, give a clear
  caveat that you cannot confirm how recent the data is — do **not** substitute
  `most_recent_data_date` or any week-derived date as freshness.

## Fiscal Week Alignment

Each company defines its own fiscal week start day — e.g.
`fiscal_week_start_day: "Tuesday"` means weeks run Tuesday → Monday. **Never**
assume Monday–Sunday, Sunday–Saturday, or ISO/calendar weeks.

- The authoritative value is `calendar_config.week_start_day` /
  `week_end_day` from the reporting freshness context fetched above.
- "This week" means the **current in-progress fiscal week** — the week
  containing `latest_safe_data_date`. Query it from its fiscal start date
  through `latest_safe_data_date` and present it as week-to-date.
- For "last week", complete-week overviews, or week-over-week comparisons, use
  `latest_complete_business_week.start_date` / `end_date` from the freshness
  context, or resolve via `client.fiscalCalendar.resolveFiscalWeek` — both
  already respect the company's configured week start day.
- When constructing any weekly range by hand (e.g. "the week of July 10"),
  align its start to the company's `week_start_day`, not to Monday.
- Endpoints that take a `week` parameter expect the **fiscal week start
  date** — a date falling on the company's `week_start_day`, which is not
  necessarily a Monday.

## Date Defaults

- **"Latest" / "most recent" defaults to the freshest data available — even if
  the current fiscal week is still in progress.** End the range at
  `latest_safe_data_date` and include the in-progress week, presented as
  week-to-date (e.g. "data through YYYY-MM-DD; the current week is still in
  progress"). Do **not** default to the last complete week — falling back to
  `latest_complete_business_week` for a "latest sales" question hides the most
  recent days of data.
- For weekly endpoints on a "latest" question, set `week` to the start of the
  **current in-progress fiscal week** (the week containing
  `latest_safe_data_date` — resolve via
  `client.fiscalCalendar.resolveFiscalWeek({ reportEndDate: latest_safe_data_date })`
  or compute from `week_start_day`) and `to` to `latest_safe_data_date`.
- Use `latest_complete_business_week.start_date` / `end_date` **only when the
  user explicitly asks for a complete week** (e.g. "last full week", "weekly
  summary", "last week's numbers", week-over-week comparisons). Fall back to
  `most_recent_data_date` (the first day of the company's fiscal week) + 6
  days only if freshness is unavailable, and present it as the latest complete
  week — not as the data-through date
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

The captured error fields (`status`, `body`, `message`) are for **your reasoning only** — they may contain internal system or infrastructure details. Never surface a raw error to the user. Respond with brief product-facing language (e.g. "I couldn't pull that data — want me to try a different period?"), and if the request is out of scope, use the [ROGER Handoff](#roger-handoff).

## User Request

$ARGUMENTS

## Requirements

- ALWAYS extract only the fields needed to answer the question — never print full responses
- If a company ID is needed, query `client.companies.list()` first to find it
- Use `"corporate"` as the default location unless the user specifies one
- Cap every date range at `latest_safe_data_date` from the reporting freshness context — never assume data exists up to today's calendar date, and never present the weekly anchor (`most_recent_data_date`, or week start + 6) as the data-through date
- Align every weekly boundary to the company's fiscal week start day (`calendar_config.week_start_day` from the freshness context) — never assume weeks start on Monday
- For "latest"/"most recent" questions, always deliver data through `latest_safe_data_date` — including the in-progress fiscal week as week-to-date. Never answer a "latest" question with only the last complete week unless the user explicitly asked for a complete-week overview
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
