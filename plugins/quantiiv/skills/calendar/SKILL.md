---
name: calendar
description: |
  The Quantiiv BUSINESS calendar — a restaurant company's record of dated operational events
  that give context to store performance. Use when the user asks about, or wants to record, a
  business or store event: promotion, promo, LTO, limited time offer, BOGO, closure, closed for
  remodel, grand opening, store event, observed holiday. Examples: "what promos ran in June",
  "was there a promo on the 14th", "is the store closed on the 4th", "any store events next
  month", "log a BOGO for next Tuesday", "record that Midtown is closed for remodel", "archive
  that promo". Not a personal calendar: every Quantiiv event belongs to a company and carries a
  company-wide, corporate, per-store, or access-group scope, so this skill cannot see meetings,
  appointments, availability, or anything in Google Calendar, Outlook, or iCal. Finds and records
  dated business events only — for sales, labor, weather, or fiscal metrics use the `query` skill.
allowed-tools: Read, mcp__quantiiv__list-companies, mcp__quantiiv__list-calendar-events,
  mcp__quantiiv__get-calendar-event,
  mcp__quantiiv__list-calendar-facets, mcp__quantiiv__list-calendar-categories,
  mcp__quantiiv__list-access-groups, mcp__quantiiv__get-holiday-settings,
  mcp__quantiiv__list-locations, mcp__quantiiv__create-calendar-event,
  mcp__quantiiv__update-calendar-event, mcp__quantiiv__archive-calendar-event,
  mcp__quantiiv__create-calendar-category
argument-hint: <question about the Quantiiv business calendar, or a store event to record>
---

# Quantiiv Business Calendar

Find and record the dated operational events — promotions, closures, remodels, grand openings,
observed holidays — that give context to store performance. This skill orchestrates typed MCP
tools; it never constructs a request by hand. For sales, labor, weather, or fiscal metrics, use the `query`
skill instead. When a question needs both ("did the BOGO lift sales?"), resolve the event's dates
here first, then get the metrics from `query`.

## Not Your Personal Calendar

This skill covers the **Quantiiv business calendar** — a company's record of dated operational
events (promotions, closures, remodels, holidays) that give context to store performance. It is
not a personal calendar and cannot see meetings, appointments, or availability; every Quantiiv event
belongs to a company and carries a company, corporate, per-store, or access-group scope, so a
personal event cannot be represented in it. If the
user meant their own schedule or a Google/Outlook calendar, say so plainly and stop — do not search
the business calendar for it, and **never report "no events" for a personal question**, which would
imply this skill had looked at their schedule.

## Company Resolution

Resolve the company via the `list-companies` tool before any calendar lookup:

1. If several companies are returned, ask the user which one to use.
2. If only one, use it automatically.
3. Cache the resolved company for the rest of the conversation.

## Tools

Every tool call is typed — you never build a URL or a JSON body by hand.

**Reads:**

| Tool | Use it to |
|---|---|
| `list-calendar-events` | The primary lookup. `startDate` and `endDate` are both required. |
| `get-calendar-event` | Full detail on one event, once you have its `id`. |
| `list-calendar-facets` | Cheap orientation — the categories and tags actually in use. Call before any tagged write. |
| `list-calendar-categories` | Resolve a category name to its `categoryId` before using one. |
| `list-access-groups` | Resolve a named access group before using an `audienceId`. |
| `list-locations` | Resolve a store name to a location id. Never invent one. |
| `get-holiday-settings` | The company's observed-holiday configuration. |

**Writes:** `create-calendar-event`, `update-calendar-event`, `archive-calendar-event`,
`create-calendar-category`. See [Writing to the Calendar](#writing-to-the-calendar) before using
any of these.

## Date Discipline

The calendar is **forward-looking** — do not anchor it to a company's most-recent-data-date the way
`query` anchors analytics. That rule is about data lag; the calendar has none.

- Anchor to **today's date**, and look forward freely.
- Always pass **both** `startDate` and `endDate` — the API only expands recurring events when both
  are present.
- Default window when unstated: the current month. Widen on request, and state the window you used.
- When correlating a calendar answer with sales, labor, or weather, the **metrics** side still clips
  to that data's own availability window — say so rather than implying analytics exist for a future
  promo.

## Access Honesty

`list-calendar-events`, `get-calendar-event`, and `list-calendar-facets` return a `viewer` field.
Reason from it, not from memory or inference. Category, access-group, and holiday lookups do **not**
carry `viewer` — and neither do write responses, so read `viewer.canCreate` from one of the three
lookups above *before* you write, never from the result of the write.

> When `viewer.sees` is `"subset"`, your answer must not assert completeness — say "the events
> visible to you", "no events visible to you in that window". Never "there are no events" or
> "that's everything on the calendar". When `viewer.sees` is `"all"`, you may state absence plainly.
> `viewer.scopeNote` is product-safe wording you may use verbatim. Never restate the filtering
> mechanism, and never name a role to the user.
>
> **`total` is the count of event *series* visible to you — not the count that exists, and not the
> number of rows you got back.** `data` carries expanded occurrences, so one recurring series can
> become many rows: `total` and `data.length` count different things and comparing them proves
> nothing. Use `page` and `limit` to decide whether more pages exist, and honour `truncated`.

Causality, specifically:

- **Presence is never causality.** You have no counterfactual: you cannot know what the 13th would
  have looked like without the BOGO. So any claim that the event moved the metric is one you cannot
  support — however it is phrased, and including implying it by juxtaposition or by ranking events
  as "the reason". Resolving an event's dates so `query` can pull the metrics is this skill's job;
  concluding the event *moved* the metric is not. Report the co-occurrence and stop — *"a BOGO ran
  on the 13th"*. Hand over the dates and the facts; the conclusion belongs to the operator, who
  knows their business.
- **Absence is not notable — but answer a direct question.** "What promos ran in June?" is a direct
  question, and "no events visible to you in June" is the correct, responsive answer — the viewer
  rules above cover that case exactly. But never volunteer "I checked the calendar and found
  nothing" as part of explaining a metric, and never let an empty result become "the spike is
  unexplained". The test: was the calendar's contents *what the user asked about*, or *evidence you
  went looking for*? Report the first; never report the second's emptiness.

Plus:

- Never invent an event a lookup did not return.
- Never skip a lookup on a hunch that something is out of scope.
- If a lookup returns nothing and the user expected an event, do not conclude the event doesn't
  exist. Say you don't see it, and offer the Console or ROGER.
- Never explain invisibility in internal terms — describe *reach* ("everyone at your company", "the
  stores you named"), never *rank*, and never name a role.
- Never surface a raw error body.
- Never offer to manage access groups — that's Console-only. (Creating, updating, and archiving
  events is in scope — see [Writing to the Calendar](#writing-to-the-calendar).)

## Exposure Model

This skill only exposes the tools bound in its frontmatter and documented here — treat that as an
explicit allowlist: if a capability is not listed here, it is intentionally not exposed — do not
attempt to reach it **even if a method appears to exist**.

In particular:

- **Archived and deleted events aren't available here** — they're in the Console. If a user asks for
  them, say that, and do not attempt a lookup.
- Hard delete is never exposed. To remove, retire, or cancel an event, archive it.
- Renaming or deleting a category is Console-only. This skill can only *create* a category.

## Writing to the Calendar

**Before your first create, update, or archive in a conversation, read `creation-reference.md`.
This is a precondition, not a suggestion — it carries the scoping rules and failure handling, and
this file does not.**

## Response Handling

- `accessPolicy` is authoritative. `visibility` and `affectedLocationIds` are legacy facades —
  ignore them.
- `source === "system:holiday"` marks a system holiday, not something the operator scheduled. Worth
  distinguishing: "Independence Day (holiday)" vs. "BOGO Wings (your promo)".
- `truncated: true` means the window had more recurring occurrences than could be expanded — narrow
  the window.
- `total` counts event *series*; `data` carries expanded occurrences. Never compare them to judge
  completeness — use `page`/`limit` to paginate, or narrow the window. Never silently present page
  one as the whole answer.
- Cite an occurrence by its `id` **and** `occurrenceDate`.

## Errors

Every calendar tool error carries a typed `code`. Map the code to copy below by table lookup —
never read the raw message text to the user.

> The captured error fields are **for your reasoning only** — they may contain internal system
> details. Never surface a raw error to the user.

| `code` | What you say |
|---|---|
| `scope_not_permitted` | "That one reaches beyond your stores, so I can't record it here. I can draft it for the Console, or send it to ROGER." |
| `credential_missing_write` | "Your Quantiiv connection is set up for reading the calendar but not for changes — run `/quantiiv:setup` to update it." |
| `conflict_stale` | Someone changed the event since you read it. Re-read it, show the user what changed, and ask before retrying. **Never blind-retry.** |
| `near_duplicate` | A 409 — **the write did not commit**. Not a failure to report as one: it means the name already exists in another form. See `creation-reference.md`, then file under the existing name. |
| anything else | "I couldn't record that — want me to try again?" Offer the Console or ROGER. |

**Never say to the user:** "interactive user required", "developer token", "session", "sign in",
"Firebase", "Firestore", "permission denied", "403", a code role name, or any error text verbatim.

## Presentation

- Use a markdown table for a multi-event answer (title, dates, category, scope).
- Use prose for a single event.
- Keep the plugin voice: product-facing, no internal nouns, no tooling references.

## ROGER Handoff

Deep or exploratory calendar-plus-analytics questions ("build me a promo effectiveness study")
route to **ROGER**, Quantiiv's email analyst, the same way `query` hands off — do not dead-end with
a limitation message:

1. Draft an email to `roger@quantiiv.com`: a subject naming the brand and the question, and a body
   built from the user's request plus any dates or scope already resolved this session.
2. Present it with product-facing language and offer a ready `mailto:` link.
3. The user sends it from their own Quantiiv-account email — you cannot send on their behalf.

Also route to ROGER or the Console, without explaining in internal terms, for anything this skill
does not expose: a request to permanently remove an event (offer archive instead), a question about
an archived event, or a request to manage access groups.
