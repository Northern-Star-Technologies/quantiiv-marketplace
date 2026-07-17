# Creating, Updating, and Archiving Calendar Events

Load this file before your **first** create, update, or archive in a conversation. Writes are the
risky half of this skill — a wrong read produces a bad answer; a wrong write publishes a corporate
event to every store, or buries a promo nobody can see.

## The one rule that matters most

> When uncertain, default to the narrowest scope that captures the event's real reach —
> **overscoping leaks access.**

There is no safe default: `accessPolicy` is required on every create, and the API rejects a create
whose scope resolves to nobody. Picking a scope wider than you meant has already published to
everyone it names — bias to the narrowest plausible reach, and ask rather than guess.

## Scoping — read what you're allowed to create off `viewer.canCreate`

`list-calendar-events`, `get-calendar-event`, and `list-calendar-facets` carry
`viewer.canCreate.baseScopeTypes` — the list of scope types you're actually permitted to use. Write
responses do **not** carry `viewer`, so read it from one of those lookups *before* you write. **Use
only a scope type that appears in that list.** If the type you want isn't listed, the event is
scoped beyond what this caller can record — don't attempt the write; say so and route to the
Console or ROGER.

| Event reach | Scope type to use | Also required |
|---|---|---|
| One or more named stores | `locations` | `locationIds` — resolve names via `list-locations`, but every id must also appear in `viewer.canCreate.locationIds`. Never invented |
| Every store in the chain | `company` | `scopeJustification` — state, in the operator's own words, why it reaches beyond specific stores |
| Restaurant Admins only (an office closure, a leadership offsite) | `corporate` | `scopeJustification`, same as above |
| Specific access groups only | *(omit base scope)* | `audienceIds`, resolved from `list-access-groups` — never invented |

Access groups are **additive** on top of the base scope — see `access-reference.md`.

**A Restaurant Manager is store-scoped by construction.** `viewer.canCreate.baseScopeTypes` for a
Restaurant Manager will only ever list `locations`, and every `locationId` must be one of their own
stores. If a Restaurant Manager reports a chain-wide or corporate-only event, do not write it — say
it reaches beyond their stores, and offer to route it to the Console or ROGER.

If `scopeJustification` cannot be stated from what the user actually told you, do not widen the
scope — ask instead.

## Location and group ids — a closed list of legal sources

An id is only legitimate if it came from one of these:

1. `viewer.canCreate.locationIds` (a caller's own assigned stores), or
2. a `list-locations` result — but this returns **every** store in the company, not just the ones
   this caller may write to. For a store-scoped caller, an id from here is only usable if it also
   appears in `viewer.canCreate.locationIds`; writing outside that list is rejected, so intersect
   first rather than discovering it as a failure, or
3. a `get-calendar-event` / `list-calendar-events` result for an existing event, or
4. (for access groups only) a `list-access-groups` result.

If the user's reference doesn't resolve to **exactly one** id from those sources, ask a terminal
question naming the ambiguity. Do not guess, and do not reuse an id you happen to have in context
unless it came from one of these four places moments ago.

## Categories

- `categoryId` is a UUID — never pass a display name where an id is expected.
- **Prefer an existing category, hard.** Call `list-calendar-categories` first and reach for a label
  an operator would already recognize. With category creation open to every writer, this skill is
  now the most likely source of taxonomy drift in the system — left unchecked it will happily mint
  "Promo", "Promotion", and "Promos" across three stores in a week.
- Creating a new category is the exception: offer it, create it only on the user's confirmation via
  `create-calendar-category`, and use only the id the tool returns.
- **Tags are the right answer when the user doesn't want a new category** — omit `categoryId`, pass
  `tags` instead. This is a filing choice, not a fallback for a permission you lack.
- A category, once created, can't be renamed or deleted from here — that stays Console-only, because
  a label other stores are filed under isn't this skill's to change.

### When a tag or category name comes back as a near-duplicate

This comes back as a **409 conflict: the write did not commit.** But it is not a failure to hand
back to the user as one — it means the thing you are naming already exists under a slightly
different name. Repair it and retry once, confirmed; do not report it as a broken write.

**Prevent it.** Call `list-calendar-facets` before any tagged write and reuse an existing tag
verbatim. Never use tags as sequence markers or idempotency keys — `promo_002` and `promo_001` read
as near-typos of each other and will reject each other. Put run markers in the description instead.

**When it happens:**

1. Read the candidates in the response.
2. If one means what you meant → use it exactly as returned. Done.
3. If none means what you meant:
   - **A tag** → omit it. Put the distinction in the description. An event with fewer tags is
     correct; an event carrying a tag that means something else is wrong.
   - **A category** → stop and ask the user which existing category to file it under.
4. **One repair attempt.** If the repair also rejects, stop and ask. Never a third attempt.

Never invent a variant to get past this — no suffixes, no punctuation swaps, no "…2." A name chosen
to defeat the check creates the exact duplicate the check exists to prevent.

Never tell the user a name was "rejected" or mention a similarity check. Say you filed it under the
existing tag or category, and name it.

## Concurrent creates can duplicate an event — this is a known, accepted gap

**There is no server-side guard against two people creating the same event at once.** If two users
both ask to "add the BOGO promo" close together, two events are created, and nothing on the server
catches it. The "look up before you write" step below is best-effort — a read-then-write check, not
a lock — and it cannot close this window by itself.

What actually keeps this tolerable: **every write is confirmed with the user first**, so the
duplicate window is a human-in-the-loop window, not an unattended one. If you ever suspect a
duplicate was created, say so plainly and offer to archive the extra one — do not silently leave two
copies for the user to find later.

## Write discipline

1. **Look up before you write.** Call `list-calendar-events` for the same stores and window to check
   for an existing match. Never claim an event does or doesn't exist without a lookup result. This
   is best-effort, not a guard — see above.
2. **Amend, don't duplicate.** To change an event: look it up, then pass its `id` and
   `expectedUpdatedAt` to `update-calendar-event`.
3. **Never hard delete.** To remove, retire, or cancel an event: `archive-calendar-event` with `id`,
   `expectedUpdatedAt`, and a concise reason. Hard delete isn't exposed.
4. **Claim success only after the tool reports commit.** Never say "I've added it" before the write
   actually returns.
5. **Report partial state exactly.** If a category commits and the event write then fails, say so
   precisely — never roll the category back yourself, and never claim the event was recorded.
6. **Re-look-up after creating a category**, before creating the event — another event may have
   committed in the meantime.
7. **On a stale-write conflict:** someone else changed the event since you read it. Re-read it, show
   the user what changed, and confirm before retrying. Never blind-retry.

## Confirmation — render reach, not fields

**Confirm every write with the user before sending it**, and the confirmation must describe **who
sees it**, in people, not in field values:

```
Title:      BOGO Wings
Dates:      2026-08-01 → 2026-08-14
Category:   Promotions
Visible to: every store in the chain     ← or: the 3 stores you named (Downtown, Airport, Mall)
```

Never show the user a raw scope type, field name, or internal value. If the "visible to" line would
surprise the user, the scope is probably wrong — go back and narrow it before you ask for
confirmation, not after.

Confirmation catches typos and lets the user veto a scope they didn't intend. It does **not**, by
itself, prove the scope is right — that's why the reach line has to be in plain language the user
can actually evaluate, not a repeated-back field value they'll rubber-stamp.

## Not exposed

| Excluded | Where it lives instead |
|---|---|
| Hard delete | Console only. Use archive here. |
| Renaming or deleting a category | Console only. |
| Access-group management | Console only. |
| Setting an event's status directly | Not a field you can write — archive is the lifecycle path. |
