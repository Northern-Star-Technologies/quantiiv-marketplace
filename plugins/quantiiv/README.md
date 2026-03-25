# Quantiiv Plugin for Claude Code

Query your Quantiiv analytics data directly from Claude Code. Ask business questions about sales, products, pricing, and elasticity — Claude fetches the data and presents actionable insights.

## Features

- **Natural language queries** — Ask "what were my top sellers last week?" and get formatted results
- **Proactive analysis** — The analyst agent detects business questions and fetches data automatically
- **Setup wizard** — `/quantiiv:setup` installs the SDK and configures credentials
- **Session checks** — Alerts you if the SDK or credentials are missing when you start a session

## Prerequisites

- Node.js 18+
- A Quantiiv API key and API URL

## Installation

Install the plugin in Claude Code:

```bash
claude plugin add /path/to/quantiiv-plugin
```

Or for development, run with:

```bash
claude --plugin-dir /path/to/quantiiv-plugin
```

## Setup

Run the setup skill to install the SDK and configure credentials:

```
/quantiiv:setup
```

This will:
1. Install `@quantiiv-ai/sdk` globally
2. Configure `QUANTIIV_API_KEY` in Claude Code settings
3. Verify the connection works

## Usage

### Explicit queries

```
/quantiiv:query what were my top sellers last week?
/quantiiv:query show me pricing opportunities for beverages
/quantiiv:query how is the Chicken Sandwich doing across locations?
```

### Natural language

Just ask business questions — the analyst agent triggers automatically:

- "What are my top movers by net sales?"
- "Show me menu group metrics for this week"
- "List my companies and locations"
- "What pricing opportunities do I have?"
- "How did delivery sales perform last month?"

## Components

| Component | Type | Description |
|-----------|------|-------------|
| `query` | Skill | Explicit data queries via `/quantiiv:query` |
| `setup` | Skill | SDK installation and credential configuration |
| `quantiiv-analyst` | Agent | Proactive business data fetching and analysis |
| `check-setup` | Hook | Session-start check for SDK and credentials |

## Environment Variables

| Variable | Description |
|----------|-------------|
| `QUANTIIV_API_KEY` | API token for Quantiiv |

This is configured automatically by `/quantiiv:setup` in Claude Code's `settings.json`.
