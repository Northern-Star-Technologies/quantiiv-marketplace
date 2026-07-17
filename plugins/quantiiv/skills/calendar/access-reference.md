# Business Calendar Access Model

> Sourced from the gateway's `access-groups.md` knowledge doc
> (`gateway/dev/contextualizer/knowledge/access-groups.md`), derived 2026-07-16.

Load this file when you need to **explain** who can see a calendar event, or how visibility works
in general. For the everyday lookup path, `viewer` on each tool response already tells you what you
need — see `SKILL.md`'s Access Honesty section. This file is for when the user asks the "how does
this work" question directly.

## The model

Every event has one **visibility tier**, and may additionally be shared with one or more **access
groups**. Groups are *additive* on top of the tier — they can only add more visibility, never take
it away.

| Visibility | Who sees it |
|---|---|
| **Everyone at your company** | Every user at the company. |
| **Restaurant Admins only** | Not visible to Restaurant Managers. |
| **The selected stores** | People at those stores, plus Restaurant Admins. |
| **The assigned access groups** | Members of those groups, plus Restaurant Admins. |

**Restaurant Admins always see every event, at every tier.** Nothing on the business calendar is
hidden from them.

## Other things operators ask about

- **Access groups attach per event.** There is no company-wide default group — each event's group
  membership is set when it's created or edited.
- **Categories are unrelated to visibility.** A category is a name-and-color label for filing and
  filtering, nothing more. Filing an event under a category never changes who can see it.
- **There is no creation default.** Every create must state its scope explicitly — the API rejects a
  create that omits one. Nothing is inferred from who is recording the event, so never assume a
  scope: read what you may set from `viewer.canCreate` and confirm the reach with the user first.
- **Removing an event from a group removes that group's grant.** It does not guarantee the people it
  covered lose sight of the event — reach is additive, so someone may still see it through another
  scope or group, as the event's creator, or as a Restaurant Admin. Never promise that taking a
  group off an event hides it from a particular person.
- **Managing access groups — creating, renaming, or changing membership — is not exposed by this
  skill**, and not by an email to ROGER. It lives in the Console, for Restaurant Admins.

## What this file is not for

This file explains the *model*. It does not change what a lookup returns — a `viewer.sees ===
"subset"` result is still reported honestly per `SKILL.md`, whether or not the user has asked how
the model works. Never use this file to infer what a specific lookup should have returned; only a
live tool call tells you that.
