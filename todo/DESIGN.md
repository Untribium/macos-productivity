# Todo — design

A keyboard-driven todo app for open points at work, built on `OverlayKit`
(layer 6, `docs/keymap.md`; framework in `overlay/DESIGN.md`).

**Status:** design. The UI is worked out in a clickable prototype
(`prototype/todo-vim.html`, see Prototype); nothing is built in Swift yet. Name
is a placeholder.

---

## Goal & constraints

**Goal:** get an open point out of your head in a few keystrokes, without
leaving what you are doing (a daily, a Webex message), and see what is due
today at a glance. Mark it done with one key.

It is a list of **open points, not a planner**: no time slots, no priorities
beyond "when, roughly". Time spent is logged when a task is done, nothing more.

- **Capture speed comes first.** Hotkey → type → Return → gone, focus back
  where it was. Anything that slows capture is out, or optional and after.
- **Keyboard-driven,** in the overlay: no Dock icon, no app to switch to.
  vim-style keys where they fit; the real rule is "everything by keyboard", so
  a visible, selectable option is fine where vim has nothing natural.
- **Local-first.** A local store is the source of truth. The app is fully
  usable offline and with no account. Sync, if ever, is an add-on, not a
  dependency.
- **Runs on every machine:** the work machine first, the personal machine too
  (less use). Nothing tied to a work-only service in the core.
- **One user.** No sharing, no assignees.
- **Desktop first.** The phone is a nice-to-have, see Open questions.
- Same rules as the rest of the repo: no admin, no special permissions.

**Non-goals:** collaboration (the Sweden move planner is a separate project,
web-based, own repo); time planning or calendars; deep hierarchies (one level
of groups only); status workflows beyond open/done; a detail view or notes.

---

## Core loop

1. **Capture**, from anywhere: hotkey, a one-line field, type, Return. Tab
   steps the date. A link on the clipboard is offered as a pill. The panel
   closes; focus returns.
2. **The board:** what is due now (today plus overdue), with Done to the left
   and the days ahead to the right. Move with `hjkl`, one key to mark done.
3. **Triage** (occasional): send tasks to another day, reorder, group them,
   open or add links, delete.

Done tasks show in the Done column: today's and earlier ones, newest first.
History beyond that is an open question.

---

## Data model

| Field | Type | Notes |
|---|---|---|
| `id` | UUID | stable, generated locally |
| `title` | string | one line |
| `due` | date? | a **day**, no time. Menus and keys are shortcuts that resolve to a date |
| `done` | bool | the only status |
| `doneAt` | timestamp? | |
| `spent` | minutes? | logged when the task is done (or with `s`) |
| `links` | [{url, title?}] | Jira tickets, merge requests, Webex spaces, anything |
| `parent` | id? | the group a task belongs to; one level only |
| `group` | bool | the item is a group heading, not a task (see below) |
| `order` | sortable | the manual order within a day |
| `createdAt` | timestamp | |
| `updatedAt` | timestamp | bumped on every change; last-writer-wins later |
| `deletedAt` | timestamp? | soft delete, so a future sync can propagate deletions |

**Groups instead of subtasks.** A group is only a heading: it has no date, no
done state and no time of its own. Its tasks have those. A group is done when
all its tasks are; its time is the sum of theirs. It appears wherever its tasks
are (see "Split across days" under UI).

**Due buckets** (shortcuts, stored as a date): today, tomorrow, end of week
(Friday; on a Friday, see Open questions), next week (Monday), none. Overdue
tasks show in Now; their date is not changed automatically.

**Jira and GitLab:** links are recognised by pattern (`…/browse/ABC-123`,
`…/-/merge_requests/123`) and shown with short labels (`jira ABC-123`,
`gitlab !123`). Titles come from the APIs with personal access tokens, stored in
the Keychain per machine (both are fine policy-wise). A ticket key in a title
links via a per-machine base URL; without one (personal machine), keys stay
plain text.

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

Built on `OverlayPanel`. What follows is settled in the prototype; the
remaining variants are switches there and are listed under Open questions.

### The board

- **Columns in time:** Done | Now | Tomorrow | Rest of this week | Later | No
  date. Now is today plus overdue.
- **A fixed focus line:** the focused task always sits at the same height; on
  `j`/`k` the column slides under it, on `h`/`l` the columns slide sideways.
  Everything moves smoothly (about 300 ms). Each column remembers its last
  position, so `h` then `l` returns to the same task.
- **The column you are in** is frosted glass; the others are clear glass and
  faded. A marked task keeps full strength in a faded column.
- **Each task is its own card** (each group one card with its tasks), with no
  window behind the column.
- **A detail strip** above the status line shows the focused task's links and
  time; its height never changes, so nothing in the board jumps. The focused
  row never grows.
- **Order:** manual within a day (`J`/`K`). Overdue tasks start on top but are
  not pinned.

### Moving and sending

- `hjkl` moves the focus. **`HJKL` moves the task** (or the marked tasks) and
  you go along: `H`/`L` one column earlier or later, `J`/`K` up or down in the
  order. Each press is one undo step.
- **Sending** moves a task in time while you stay put; the focus goes to the
  next task. `Tab`/`Shift+Tab` and `>>`/`<<` one column later or earlier
  (`.` repeats), `t` plus a letter for a specific day: `tt` today, `tm`
  tomorrow, `tw` end of week, `tn` next week, `t-` no date. `==` sets today.
  From an overdue task, the first step later is today.
- `M` jumps to Now, `0`/`$` to the first and last column.

### Marks

- **Space marks** a task; actions then apply to the marked tasks instead of
  the focused one. Marks survive moving and sending, so mark, then Tab Tab Tab
  keeps pushing. Esc clears them. Done or deleted tasks lose their marks.
- A marked task is **lifted** (slightly raised, accent edge, shadow). Space on
  a group heading marks the tasks that card shows there, never the group as
  such.
- Columns other than the focused one centre their first marked task on the
  focus line, so marks stay in view as they move; releasing them doesn't
  scroll the column back.

### Groups

- `o` on a task turns it into a group of two (the group takes its title) and
  adds a new task; `o` inside a group adds a task to it. `O` adds a task of its
  own above. A new task left empty is discarded, and a group made by that `o`
  turns back into the plain task.
- **Split across days:** a group shows in every column where it has a task,
  with only that day's tasks and a small line for the rest (`→ 2 later ·
  ✓ 1 done`; Return unfolds it). This includes Done.
- Focus on a group or one of its tasks lights the same group elsewhere (faint
  outline), and the detail strip says where ("also: Tomorrow, Fri").
- A heading stands for its tasks shown there: `x`, sending and moving act on
  those.

### Done and time

- `x` marks done and asks for the time spent: 0 none/skip, 1 15m, 2 30m, 3 1h,
  4 2h, 5 half day, 6 full day (digits shown next to the options). `x 3` is
  "done, an hour".
- **Several tasks** (marks, or a group heading) are asked **one by one**: the
  header names the current task, which is highlighted. Return or a digit
  handles it and moves on, `Shift+Return`/`Shift+digit` applies the choice to
  all the rest, Esc stops (handled tasks stay done). One undo step.
- `s` logs time without marking done, the same way.

### Links

- `f` (or Return, or `gx`) opens the links menu below the task: short labels
  with hint letters; Return opens the selected link, a letter opens its link.
  `f` again closes it, as in Vimium. Opening a browser always takes this one
  confirming key, so a wrong link never opens by accident.
- **"+ add"** (or `o`) adds a link; `x` (or `dd`) removes the selected one.
- **Clipboard:** a fresh link on the clipboard is offered as a pill
  (`↗ gitlab !431 ×`) wherever a link or a task is created: quick capture and
  adding a link. The placeholder shows the title Return would create. Typing
  keeps the link attached; Backspace on the empty field or the × drops it. The
  pill stays offered until used or dropped (Esc doesn't count).

### Menus

Menus open **inline, below the task**, as a section of its card (same width, a
divider, no box of their own), and push the tasks below down.

### Quick capture

- One field. Return saves and closes; the list hotkey pressed while capturing
  saves and opens the list on the new task.
- A **date pill** in the field (`→ today`); Tab and Shift+Tab step it.
- The clipboard pill as above.

### Text fields

- Typing is a normal text field. **Esc on an empty field leaves at once** (a
  new task is discarded, an edited title stays as it was, the filter clears).
- **With text, the first Esc** switches to normal mode inside the field (block
  caret; `h`/`l`, `i`/`a`); the second saves and leaves. Return saves from
  either mode. The fuller vim subset is an open question.

### Search

Only a live filter for now (`/`). Search gets its own design session.

---

## Prototype

`prototype/todo-vim.html` is a single self-contained page: a fake desktop with
the overlay on it, and a rail of switches for the variants still open. Open it
in a browser; Return opens the list (standing in for `caps+Return`), `c` opens
quick capture, `,` moves the keyboard into the switches. A copy is published as
a private artifact (`https://claude.ai/artifact/VqdLyxAkF5FVyUGMRzMfjh`); the
file in the repo is the source of truth.

---

## Open questions

- **Bindings:** one hotkey for capture and one for the list, or one hotkey
  whose panel does both? Which caps keys (via the hyper channel)? Check the
  Keymap in `docs/keymap.md` first. `caps+Return` is the spike's today.
- **Variants still open in the prototype:**
  - columns: the stacked carousel (later columns stacked on the right) or
    Done | Now | Upcoming, sliding or fixed;
  - menus: separate (`t`, `s`, `f`) or one live sheet (Links, Due, Time; `h`/`l`
    change values directly, one owner per key: `t m w n -` date, digits time,
    `o x` links);
  - Tab in the list: send at once, or a date pill that sends on the next key
    or after a second (with marks, every marked task shows its own pill);
  - Lifted or dot marks; three panes or one card per task; motion speed.
- **Capture:** should Tab first turn the clipboard suggestion into editable
  text, before it steps the date? Should `o`/`O` offer the clipboard pill too?
- **Storage format:** a JSON file (simple, diffable, fine for thousands of
  items) or SQLite (queries, safer partial writes)? Leaning JSON until it hurts.
- **"End of week" on a Friday:** today, or next Friday?
- **History:** how long are done tasks kept, and is there a view for them?
- **Links:** which browser and profile (e.g. a separate profile, incognito)
  each kind of link opens in, from the per-machine config.
- **Clipboard on macOS 26:** does reading it without a paste prompt the user?
  If so, check for a URL first and read only when the pill is accepted. Probe
  in the Swift spike.
- **Webex:** there is no "copy link to a message", and bots are not allowed
  at work. Options: copy the space link and capture with your own title (no
  token), or forward messages to a private "todo inbox" space read through an
  integration (OAuth, 90-day refresh token; check that users may authorise
  integrations). Personal access tokens last only 12 hours.
- **Parked, to raise later:** a "blocked" state with a reason and a follow-up
  date; expected time per task (an "I have 15 min" filter, expected vs
  actual); capture from a screenshot (text recognised locally, for things
  without links such as Citrix windows; probe whether `screencapture -i` needs
  a permission); the fuller vim subset in text fields; turning an existing
  task into a grouped one; tags (`#`, `@`) as chips.
- **Phone (work phone):** low priority now that To Do parity is no longer a
  goal (see the decision log). If it comes back, Microsoft Graph access is
  gated on tenant consent: check with Graph Explorer
  (`GET https://graph.microsoft.com/v1.0/me/todo/lists`) before anything else,
  and never borrow another app's client ID.
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
| 2026-11-09 | **Microsoft To Do parity is no longer a goal** (supersedes the 2026-11-08 mapping entry) | Groups with dated tasks, logged time and the manual order have no clean To Do equivalent, and a To Do sync is unlikely. The model follows the UI. | Constraining the model to To Do's fields |
| 2026-11-09 | **Work out the UI in a clickable HTML prototype** first, kept in `prototype/` | Key feel, motion and layout are cheaper to iterate in a browser page than in Swift; variants sit side by side as switches. | Designing the keys on paper only; building UI variants in Swift |
| 2026-11-09 | **Columns in time with a fixed focus line** (Done, Now, then the days ahead) | Seeing tasks laid out by day makes "when" visual, and moving a task is moving it sideways. A fixed line keeps the eye still while the board moves. | A single list with date groups; a list that scrolls like a list |
| 2026-11-09 | **Groups instead of main tasks with subtasks** | A main task was really a heading. Making it one removes the "whose date, whose done" ambiguity: only tasks have dates, done states and time. Groups split across days. | Dates or done states on a parent; deeper nesting |
| 2026-11-09 | **Modeless moving: `HJKL` move the task, sending keeps the view** (Tab, `>>`, `t`+letter) | A "pick up" mode needed confirming and an Esc that reverts, which isn't vim. Every press as one undo step is simpler, and sending covers "I'll do it tomorrow" without leaving Now. | A grab mode (`v`); a separate range selection (`V`) |
| 2026-11-09 | **Marks with Space** for several tasks, shown lifted | Non-contiguous selection that survives moving and sending; actions apply to marks, otherwise the focused task. `u` covers mistakes, so no confirmations. | Contiguous range selection as the way to act on several tasks |
| 2026-11-09 | **No detail view, no notes** | Everything a detail view held has a direct key (title, date, done, time, links); context lives behind the links. | A per-task screen; a notes field |
| 2026-11-09 | **Links through an inline menu, always confirmed** (`f`, Return) | Opening a browser leaves the app; one confirming key prevents opening the wrong link. Matches Vimium/qutebrowser's `f`. | Opening the only link directly |
| 2026-11-09 | **Scripted link handling, no AI** for "review <link>" | A pattern match on the URL is instant and always right; the title comes from the Jira/GitLab API. Apple's on-device model got simple dates wrong in a test. | An on-device or cloud model in the capture path |
| 2026-11-09 | **Time spent asked on done, per task** (one by one for several) | Logged time is only useful if real; asking once and splitting or copying guesses. | Splitting one answer across tasks; copying it to each |
