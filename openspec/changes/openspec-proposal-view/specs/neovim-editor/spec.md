## MODIFIED Requirements

### Requirement: Pinned plugins
The plugin set SHALL be lazy.nvim with claudecode.nvim, opencode.nvim, diffview.nvim,
gitsigns.nvim, octo.nvim, snacks.nvim, plenary.nvim, render-markdown.nvim and vim-surround, each
pinned to a commit (tags can be force-moved). At deploy time, whenever the plugin spec changed, the
role SHALL bring every plugin to its pinned commit, and SHALL fail the run when a plugin is missing
or off its pin. Neovim SHALL never download plugins at startup.

#### Scenario: Fresh host
- **WHEN** the role has run and `nvim` starts for the first time
- **THEN** no plugin is downloaded at startup and `:checkhealth lazy` reports no error

#### Scenario: Pin bumped
- **WHEN** a plugin's commit is changed in the spec and the role reruns
- **THEN** that plugin is checked out at the new commit on the host

#### Scenario: Plugin cannot be fetched
- **WHEN** a plugin cannot be cloned, or lazy.nvim itself cannot be bootstrapped, during the role run
- **THEN** the run fails instead of reporting success

## ADDED Requirements

### Requirement: Markdown rendering
Markdown buffers SHALL render in place: headings, lists, checkboxes, code blocks and tables. Rendering
SHALL need no extra parser install and no Nerd Font. The raw text SHALL show on the cursor line, and
`:RenderMarkdown toggle` SHALL switch rendering off and back on.

#### Scenario: Proposal opened
- **WHEN** an OpenSpec `proposal.md` is opened on a host provisioned by the role
- **THEN** its headings and bullet lists render, and the terminal shows no missing-glyph boxes

#### Scenario: Editing a rendered line
- **WHEN** the cursor moves onto a rendered heading
- **THEN** that line shows its raw markdown and can be edited

### Requirement: OpenSpec change view
`:OpenSpecView [change]` and `<leader>sv` SHALL open an active change of the worktree's
`openspec/changes/` (archive excluded) in a new tab. The tab's local argument list SHALL hold its
artifacts that exist, in the order proposal, delta specs, design, tasks, with the proposal shown first.
The global argument list SHALL be left unchanged. They SHALL work with or without `MR_NAME`.

#### Scenario: Single active change
- **WHEN** `<leader>sv` is pressed in a worktree with exactly one active change
- **THEN** a new tab shows that change's `proposal.md`, and `]a` moves to its first delta spec

#### Scenario: Several active changes
- **WHEN** `:OpenSpecView` runs without an argument and two changes are active
- **THEN** a picker lists both, and the chosen one opens

#### Scenario: Name completion
- **WHEN** `:OpenSpecView <Tab>` is typed
- **THEN** the active change names are offered

#### Scenario: Missing artifact
- **WHEN** the chosen change has no `design.md` yet
- **THEN** the view opens with the other artifacts and does not create the missing file

#### Scenario: No change
- **WHEN** `<leader>sv` is pressed where `openspec/changes/` is missing or holds no active change
- **THEN** no tab opens and a warning says so

### Requirement: OpenSpec change validation
Opening the change view SHALL run `openspec validate <change> --strict` without blocking the editor.
It SHALL report success, or the failure with its findings. When `openspec` is not on `PATH`, the view
SHALL still open and a warning SHALL say validation was skipped.

#### Scenario: Valid change
- **WHEN** the view opens a change that passes strict validation
- **THEN** a notification says the change is valid

#### Scenario: Invalid change
- **WHEN** the view opens a change with a requirement that has no scenario
- **THEN** an error notification lists the validation findings, and the tab stays open

#### Scenario: No openspec CLI
- **WHEN** the view opens on a host without `openspec`
- **THEN** the tab opens and a warning says validation was skipped

### Requirement: Delta spec diff
`<leader>sd`, pressed in a buffer holding `openspec/changes/<change>/specs/<capability>/spec.md`, SHALL
open a new tab that diffs `openspec/specs/<capability>/spec.md` (left) against that delta (right).
When the main spec does not exist, the delta SHALL open alone with a notice that the capability is new.
In any other buffer it SHALL do nothing and warn.

#### Scenario: Modified capability
- **WHEN** `<leader>sd` is pressed on the delta of an existing capability
- **THEN** a new tab shows the main spec and the delta side by side in diff mode

#### Scenario: New capability
- **WHEN** `<leader>sd` is pressed on the delta of a capability with no main spec
- **THEN** the delta opens in a new tab and a notice says the capability is new

#### Scenario: Not a delta spec
- **WHEN** `<leader>sd` is pressed in `proposal.md`
- **THEN** no tab opens and a warning says the buffer is not a delta spec
