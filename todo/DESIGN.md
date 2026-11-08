# Todo — design

A keyboard-driven todo app for open points at work, built on `OverlayKit`
(layer 6, `docs/keymap.md`; framework in `overlay/DESIGN.md`).

**Status:** design, nothing built. Name is a placeholder.

---

## Goal & constraints

**Goal:** get an open point out of your head in a few keystrokes, without
leaving what you are doing (a daily, a Webex message), and see what is due
today at a glance. Mark it done with one key.

It is a list of **open points, not a planner**: no time slots, no estimates, no
priorities beyond "when, roughly".

- **Capture speed comes first.** Hotkey → type → Return → gone, focus back
  where it was. Anything that slows capture is out, or optional and after.
- **Keyboard-driven,** in the overlay: no Dock icon, no app to switch to.
- **Local-first.** A local store is the source of truth. The app is fully
  usable offline and with no account. Sync, if ever, is an add-on, not a
  dependency.
- **Runs on every machine:** the work machine first, the personal machine too
  (less use). Nothing tied to a work-only service in the core.
- **One user.** No sharing, no assignees.
- **Desktop first.** The phone is a nice-to-have, see Open questions.
- Same rules as the rest of the repo: no admin, no special permissions.

**Non-goals:** collaboration (the Sweden move planner is a separate project,
web-based, own repo); time planning or calendars; projects or hierarchies;
status workflows beyond open/done.

---

## Core loop

1. **Capture**, from anywhere: hotkey, a one-line field, type, Return. Optional
   due shortcut while typing. The panel closes; focus returns.
2. **Today view:** what is due today, plus anything overdue rolled in, plus
   undated items in a separate group. Arrows to move, one key to toggle done.
3. **Triage** (occasional): change the due bucket, edit text, add a link or a
   note, delete.

Done items stay visible, struck through, until the end of the day, then drop
into history (kept, searchable later, not shown by default).

---

## Data model

Shaped so that each field maps one-to-one onto Microsoft To Do (Graph
`todoTask`), the most likely sync target, without the core depending on it.

| Field | Type | Notes | To Do field |
|---|---|---|---|
| `id` | UUID | stable, generated locally | *(mapped via sync state)* |
| `title` | string | the open point, one line | `title` |
| `notes` | string? | free text | `body` |
| `due` | date? | a **day**, no time. Buckets are input shortcuts that resolve to a date | `dueDateTime` |
| `done` | bool | the only status | `status` |
| `doneAt` | timestamp? | | `completedDateTime` |
| `links` | [{url, title?}] | Jira tickets, Webex messages, anything | `linkedResources` |
| `createdAt` | timestamp | | `createdDateTime` |
| `updatedAt` | timestamp | bumped on every change; last-writer-wins later | `lastModifiedDateTime` |
| `deletedAt` | timestamp? | soft delete, so a future sync can propagate deletions | *(delete)* |

**Due buckets** (input only, stored as a date): today, tomorrow, end of week
(Friday; if today is Friday, next Friday?), next week (Monday), none.
Overdue items count as today in the today view; their date is not changed
automatically.

**Jira:** a ticket key in the title (`ABC-123`) becomes a link automatically,
using a per-machine base URL (`config/local`-style, not in git). On a machine
without one (personal), keys stay plain text.

---

## Storage

A single file per machine in `~/Library/Application Support/<app>/`, outside
the repo and outside any synced folder. Atomic writes (write temp, rename).
Format is an open question below.

**Sync seam:** the app talks to a small store interface (load, save, observe).
A sync adapter, if one is ever written, sits behind it and maps to the remote
using `id`, `updatedAt` and `deletedAt`. Nothing in the UI knows sync exists.

---

## UI

Built on `OverlayPanel` and the chooser pattern from the spike.

- **Capture panel:** one text field, nothing else visible. Return saves, Escape
  discards, a due shortcut can be typed or picked with a key.
- **List panel:** the today view by default; the field at the top filters, and
  can also create ("type, Return to add" when nothing matches).
- Keys inside the list (proposed): arrows or ctrl+n/p to move, Space or
  cmd+Return to toggle done, Tab to cycle the due bucket, cmd+L to add a link,
  cmd+Backspace to delete, Return to edit.

---

## Open questions

- **Bindings:** one hotkey for capture and one for the list, or one hotkey
  whose panel does both? Which caps keys (via the hyper channel)? Check the
  Keymap in `docs/keymap.md` first. `caps+Return` is the spike's today.
- **Capture syntax for due:** suffix tokens while typing (`… !tom`, `!fri`),
  a key in the panel that cycles buckets, or both?
- **Storage format:** a JSON file (simple, diffable, fine for thousands of
  items) or SQLite (queries, safer partial writes)? Leaning JSON until it hurts.
- **"End of week" on a Friday:** today, or next Friday?
- **History:** how long are done items kept, and is there a view for them?
- **Phone (work phone):** sync to Microsoft To Do through Microsoft Graph, so
  the To Do app is the phone UI and no phone UI needs building. **Gated on
  access:** the company tenant must allow a personal app registration or user
  consent. Check first: sign in to Graph Explorer with the work account and run
  `GET https://graph.microsoft.com/v1.0/me/todo/lists`. If it says admin
  approval is required, this is an IT request or not possible; do not borrow
  another app's client ID to get round it. Also check that putting work tasks
  in To Do is within policy (it is a company-managed service, so likely fine).
  Personal-machine sync, if any, is a separate question and must not touch the
  work tenant.
- **Name.**

---

## Decision log

Append-only. Each entry: what was decided, why, and what it rules out.

| Date | Decision | Rationale | Rules out |
|---|---|---|---|
| 2026-11-08 | **Separate from the Sweden move planner;** no shared core | Opposite optimizations: this one wants less structure for capture speed, that one wants more (subtasks, status, comments, assignees, server state). Different platforms too (native Swift vs web). A shared core would be a task struct in two languages. | A common task library or backend for both |
| 2026-11-08 | **Local-first, no sync stack in the core** | Must work on the personal machine as well as the work one, offline and with no account. Sync is a later adapter behind a store interface. | Building on OneDrive files, Graph, iCloud or any other sync service as the source of truth |
| 2026-11-08 | Data model maps one-to-one onto Microsoft To Do | The most plausible phone route for work is To Do via Graph, on the company's own Microsoft 365. Matching fields now (date-only due, done, links, soft delete, updatedAt) makes a later adapter a mapping, not a migration, and costs nothing. | Fields with no To Do equivalent in the core model, unless decided explicitly |
| 2026-11-08 | Lives in `todo/`, its own Swift package depending on `../overlay` | Keeps the framework free of app code and the dependency one-way (`overlay/DESIGN.md`). | Adding the todo app as another target inside the overlay package |
