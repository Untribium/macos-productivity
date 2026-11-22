# IntelliJ IDEA settings

Read from the work machine's IntelliJ IDEA 2026.1 config on 2026-11-22. The new
machine starts from stock; only the items under **Apply** are carried over. The
rest of the old customisations are listed under **Previously customised, not
applied**, so they are documented if they are missed later.

Config directory: `~/Library/Application Support/JetBrains/IntelliJIdea2026.1/`.
Copyable files are in `docs/intellij/`, laid out like the config directory.

Not captured on purpose: data source and driver settings, `ssl/`, the licence
key, git hosting and Kafka settings (may hold server names or credentials),
recent projects, trusted paths, the IdeaVim history and jump list
(`vim_settings_local.xml`: search terms and file paths from work code), and the
custom spell-check dictionary (project jargon).

## Apply

With the IDE closed, copy these into the config directory (they replace any
file of the same name there), or do the same in the Settings UI.

| Copy | Effect |
|---|---|
| `docs/intellij/keymaps/macOS copy.xml` and `docs/intellij/options/mac/keymap.xml` | keymap "macOS copy", made active |
| `docs/intellij/codestyles/Default.xml` | Java: no wildcard imports, continuation indent 4 |
| `docs/intellij/options/ui.lnf.xml` | compact tree indents, tree indent guides, tab close button on the left, Search Everywhere preview |
| `docs/intellij/options/vim_settings.xml` | IdeaVim key ownership, as on the old machine |

Then by hand:

- **Rainbow highlighting:** Settings › Editor › Color Scheme › Language Defaults
  › Semantic Highlighting (the old scheme had it on for the default language).
- **Extra page at bottom:** Settings › Editor › General, "Show additional page
  at the bottom" (`ADDITIONAL_PAGE_AT_BOTTOM` in `options/editor.xml`).
- **Undo limits:** Help › Find Action › Registry: `undo.documentUndoLimit` =
  1000, `undo.globalUndoLimit` = 100.
- **Terminal:** Settings › Tools › Terminal, "Use Option as Meta key" on
  (`useOptionAsMetaKey` in `options/terminal.xml`). Alt combos like `alt+b` and
  `alt+f` then work, but Option no longer types special characters there.
- **`~/.ideavimrc`:** comes with the dotfiles. It sources `~/.vim/vimrc` and maps
  `J` to `:tabnext` and `K` to `:tabprev`.
- **Plugins:** IdeaVim, Rainbow CSV, the Claude Code plugin, PlantUML
  integration (needs Graphviz: `brew install graphviz`, then set the `dot`
  path in its settings) and Avro schema support.

### The keymap

"macOS copy", parent `Mac OS X 10.5+`. Bound:

| Action | Shortcuts |
|---|---|
| Terminal tool window | `alt f12`, `cmd 3` |
| Close all editors | `shift cmd w` |
| Next / previous splitter | `alt tab` / `shift alt tab`, plus `shift cmd j` / `shift cmd k` |
| Rename | `shift f6`, `shift cmd r` |
| Select in project view | `shift cmd p` |
| Show history for block (history of the selected lines) | `shift cmd g` |

Left unbound because the stock key is taken by something above, or by Vim:

| Action | Stock key | Taken by |
|---|---|---|
| Find tool window | `cmd 3` | Terminal |
| Replace in path | `shift cmd r` | Rename |
| Find previous | `shift cmd g`, `shift f3`, `ctrl shift l` | History for block |
| VCS push | not in the bundled keymaps; probably `shift cmd k` | Previous splitter |
| Duplicate line | `ctrl d` | IdeaVim (scroll half page) |

The caps-based navigation layer (`docs/keymap.md`) replaces the old `ctrl j/k/n/p`
list navigation, so none of that is carried over.

## Previously customised, not applied

Kept stock on the new machine for now. Listed so they can be restored.

**Keymap**
- `ctrl j` / `ctrl k` (and stock `ctrl n` / `ctrl p`) to move down/up in lists and
  popups. Quick documentation had `ctrl j` removed to avoid the clash, and kept
  `f1` and `ctrl` + middle click. Cut to line end (`ctrl k`) was unbound for the
  same reason.
- Compare with same repository version moved from `ctrl d` to `shift alt d`.
- Hide active window (stock `shift Escape`) and file chooser "go to module" (stock
  `ctrl 3`) unbound; no clash is visible, so probably to avoid accidents.
- Light-edit "go to opened file" on `shift cmd p`.
- IdeaVim: the IDE owned `ctrl j` and `ctrl k`, which are only needed with the
  list navigation above.

**Look**
- New UI on, with the Dark scheme changed: class names `#94bcd1`, sticky-lines
  background cleared.
- Tab limit 20 (stock is 10), console buffer overridden to 16 MB, minimap
  aligned left.
- Tool window layout "Custom": Project, Commit and Structure on the left;
  Version Control, Problems, Terminal and Services at the bottom; Notifications,
  AI Assistant, Database and Gradle on the right.

**Editor**
- Breadcrumbs off; commenting a line keeps the caret in place
  (`editor.comment.line.caret.down` off).
- Inlay hints: Java implicit types off; Java lambda parameter, method chain and
  annotation hints on; Kotlin lambda, type and method-chain hints off, Kotlin
  parameter hints on; TypeScript, JavaScript and SQL hints on.
- Java: EditorConfig support disabled.
- Find in Files scope "Project Files" with masks `*.css`, `*.html`, `*.xml`,
  `*.jsp`, `*.properties`, `*.java`.
- Safe delete off; rename and move do not search comments or text.
- No confirmation on re-run with termination; native macOS file chooser.

**File types:** `*.plantuml` as PlantUML, `*.csv` unmapped from the CSV/TSV
type, `~/.kube/config` as YAML.

**Runtime and plugins**
- `idea.vmoptions` had `-Xmx4096m`.
- Plugins not carried over: better_direnv, diagrams.net integration. The
  JetBrains Space plugin was disabled.

## Open

- Project setup (JDKs, Maven repository macro, Node and Graphviz paths) is
  deliberately not written down yet; it is to be decided together with the
  project setup.