---
name: query
description: This skill should be used when the user asks about "sales data", "top sellers", "menu items", "product performance", "elasticity", "pricing plans", "company locations", "menu groups", "store performance", "weekly sales summary", or any Quantiiv analytics metrics. Also triggered by questions like "what were my top movers", "show me sales trends", "how is this product doing", "list my companies", "get pricing opportunities", "compare store performance", "revenue by menu group", "daily sales for [item]", "which items should I reprice".
allowed-tools: Bash
argument-hint: <question about your business data>
---

# Quantiiv SDK Query

Query Quantiiv analytics data programmatically using the `@quantiiv-ai/sdk` npm package. Always use this SDK-based approach rather than raw API calls to keep response payloads out of context. Write and execute Node.js scripts that call SDK methods and extract only the fields needed to answer the question.

## Prerequisites

Ensure the SDK is installed globally and environment variables are configured:

```bash
# Check SDK availability
node -e "require('@quantiiv-ai/sdk')" 2>/dev/null || echo "SDK not installed"
```

If not installed, prompt the user to run `/quantiiv:setup` first.

## How to Query

Write a Node.js script and execute it via Bash. Always include error handling:

## Company Resolution

Before querying company-scoped data, resolve the company ID:

1. Call `client.companies.list()` to get available companies
2. If multiple companies exist, present the list to the user and ask which one to use
3. If only one company exists, use it automatically
4. Cache the company ID for subsequent queries in the same conversation

## Date Defaults

- Use the most recent Monday as the default `week` start date
- Use today's date as the default end date when `to` or `endDate` is needed
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
node -e '
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
- For date ranges, use the most recent Monday as the default week start
## Available Methods

See [api-reference.md](api-reference.md) for the complete method list with parameters.
