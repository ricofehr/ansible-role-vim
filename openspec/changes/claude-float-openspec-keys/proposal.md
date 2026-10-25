# Proposal

## Why

Each MR window splits Neovim and the agent side by side, so neither gets the full width, and Claude
can only be reached by switching pane. Moving Claude into a float inside Neovim lets the window hold
a single full-screen editor pane, while keeping the IDE bridge (selections, diagnostics, native diffs).
It also lets Neovim send the OpenSpec commands straight to that Claude session.

## What Changes

- claudecode.nvim runs Claude in an embedded snacks float (90% x 90%, rounded border) instead of
  running no terminal. Claude starts at the git root of Neovim's working directory (the worktree), whatever buffer is current. Sending a selection focuses the float.
- `Alt+,` opens or focuses the float from normal and visual mode, and hides it from inside the float.
  `Esc` stays with Claude (interrupt).
- Proposed diffs open in their own tab, with the Claude terminal hidden there.
- New keys: `<leader>aC` (continue the last session), `<leader>ar` (pick a session). The existing
  `<leader>as`, `<leader>ab`, `<leader>aa` and `<leader>ad` are unchanged.
- New OpenSpec keys on the `<leader>s` prefix, sent to the float: `se` explore, `sp` propose (typed,
  not submitted, so the change name can be added), `sa` apply, `sA` archive. `so` picks a file
  under `openspec/changes/`. opencode keeps `<leader>oa` / `<leader>os`.
- `<leader>mr` now diffs the working tree against the fork point with the MR base, so uncommitted
  changes to tracked files (for example from a background session) show too; new untracked files
  stay under `<leader>mu`. Before, it showed committed work only
  (`base...HEAD`).
- The pins and the `MR_NAME` guard are kept. A `claude --ide` started next to Neovim (the split layout
  of `mr`) still attaches as before.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `neovim-editor`: the per-worktree agent bridge gains an embedded Claude float and its keys, a
  new OpenSpec key map requirement is added, and the MR review map changes its diff range.

## Impact

- Branch: `feat/claude-float-openspec-keys`
- Files: `files/agentic-mr.lua`, `README.md`. No task, variable or plugin pin changes, so hosts
  keep their pinned plugin set.
- Hosts: on macOS, `Alt+,` needs the terminal to send Option as Alt (Ghostty:
  `macos-option-as-alt = left`). This is host configuration, not done by the role. The README says so.
- Pairs with the single-pane layout of `mr` (a separate change in `claude-user-settings`). It works
  without it too.
