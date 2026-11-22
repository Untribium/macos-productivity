# Claude Code setup: the ideas

Not a backup and not a script. This records *what* the Claude Code setup is
for and *why*, so it can be rebuilt by hand on a new machine instead of
copied around. Details live in the files themselves; rebuild them fresh and
let them diverge per machine if they need to.

## Layout

Claude Code reads one config directory per profile, chosen with the
`CLAUDE_CONFIG_DIR` environment variable. One shell alias per profile sets
it (for example `claude-work='CLAUDE_CONFIG_DIR=~/.claude-work claude'`), so
work and private setups never share memory, skills or login. Everything
below lives in that directory.

## What is worth rebuilding

### Global instructions (`CLAUDE.md`)

Short, personal, applies to every project. Mine covers one theme: how to run
builds and tests without flooding the context.

- Redirect all output to a scratchpad file, in its own Bash call, and read
  only the summary and failures afterwards.
- Never chain commands with `&&`, pipes or variables: compound commands can't
  be matched by "always allow" permission rules and force a prompt each time.
  Run `cd`, the command and the log inspection as separate calls.
- Write the rules *into this file*, not into a project memory. A global file
  that says "read memory X" only works in the one project that has X.

### Hook: refuse noisy builds

A PreToolUse hook on Bash that blocks a build or test command unless its
output is redirected to a file, and prints the reason to Claude. Rules do not
enforce themselves; a hook does. Exit code 2 blocks, stderr is what Claude
sees. It also catches one known foot-gun (a module flag that makes Maven use
a stale jar). Needs `jq`. Reference the hook by a home-relative path so it
survives a different username.

### Memory

Plain files, one fact each, with a small frontmatter (name, description,
type) and an index file that is loaded every session. Types: user, feedback,
project, reference. What turned out worth keeping:

- **Feedback** from corrections, with the reason, so edge cases can be judged:
  quiet test runs, simple Bash commands, spelling variant, commit type
  conventions, ask before introducing new patterns, scope agent searches
  narrowly.
- **Project** facts that the code does not show: what is being decommissioned,
  what a task is really for.
- **Reference**: how to reach an external system and the conventions around it.

**Memory is keyed by the project's absolute path.** The folder name is the
real path with every non-alphanumeric character replaced by a dash (symlinks
resolved). A different path on a new machine means the old memory is silently
not found, so the memory has to be put under the new slug by hand, or simply
re-learned. Dashes make the slug impossible to turn back into a path.

### Skills and mods

- **Quote mod:** type `>>` in the prompt, fuzzy-pick an earlier sentence of the
  conversation, and it is inserted as a quote. Keyboard only. It is a plugin
  folder in the user skills folder, auto-loaded and hot-reloaded. Lessons that
  cost time to find:
  - mods get no key-press event, only prompt edits and cursor moves;
  - Enter clears the box before the submit hook runs, so "cleared means
    cancel" must be deferred a moment;
  - a dropped submit always shows a warning and restores the text afterwards;
  - the band above the prompt can't take focus by itself, so it is driven from
    the prompt's own edits; the prompt is turned into the search line while
    picking, on a *middle* line, so up and down reach the hook instead of
    scrolling prompt history;
  - the mod's own README is the place for the rest; read it before editing.
- **Chat search skill (not being rebuilt),** the ideas worth keeping if
  something similar is built again:
  - search a **local full-text index** (SQLite FTS5) rather than calling the
    chat API per question; check "synced N hours ago" in every result and
    sync first when stale;
  - index only what the organisation's data classification allows, and keep
    that policy in constants the skill is told never to change on its own;
  - **tokens never enter the conversation:** when one expires, the user runs
    the import command themselves with the `!` prefix;
  - label bots and webhooks as such, so their posts are not attributed to a
    person; offer a flag to hide them;
  - for reports, have the model write Markdown with numbered citations and let
    a script render the page with source cards and deep links, so every claim
    can be checked.
- **Issue tracker wrapper:** a small shell script that reads the API token from
  the macOS Keychain and hands it to curl on stdin, so the token never appears
  in arguments, environment or output. Claude can call the script but never
  sees the secret; writes still get the user's go-ahead on content first. The
  built-in credential checks refuse a raw Keychain-to-curl pipe from Claude,
  which is why it is a wrapper.

## What not to carry over

Caches and state that regenerate or belong to the account: history, sessions,
shell snapshots, file history, paste cache, telemetry, daemon files, policy
and remote settings (synced from the organisation), synced skills and
plugins. Also the main account file (login, trust prompts, UI state): log in
again. No MCP servers are configured, so nothing is lost there.

## On the new machine

1. Install Claude Code, add the profile alias, run it once and log in.
2. Recreate the global instructions and the hook from the ideas above.
3. Re-add the Keychain entry for any tracker token, and any other secrets,
   by hand.
4. Rebuild memories as they become relevant: ask Claude to save a correction
   when it happens. Copy individual files only when one is clearly worth it,
   under the new path slug.
5. Check: the hook blocks a bare build command, the quote picker opens on
   `>>`, the memory index is listed in a project.
