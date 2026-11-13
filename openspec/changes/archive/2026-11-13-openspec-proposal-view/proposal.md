# Proposal

## Why

At the second OpenSpec gate the user has to confirm a proposal, but Neovim offers no good way to
read one. `<leader>so` only opens a file picker on `openspec/changes/`, one file at a time. The
markdown shows up raw, nothing is validated, and there is no way to see what a delta spec changes
compared with the main spec. In practice the proposal gets confirmed half-read, or read in another tool.

## What Changes

- New command `:OpenSpecView [change]` and key `<leader>sv`: opens a change for review in a new tab,
  with its artifacts in reading order (proposal, delta specs, design, tasks). `]a` / `[a` move through them.
  The command runs `openspec validate <change> --strict` and reports the result. With one active change,
  that change is used without asking. With several, a picker offers them. Change names tab-complete.
- New key `<leader>sd`: from a delta spec buffer, opens a diff against the matching main spec
  `openspec/specs/<capability>/spec.md` in a new tab. A new capability has no main spec, so its delta
  opens alone, with a notice.
- New plugin **render-markdown.nvim**, pinned by commit: markdown buffers render in place (headings,
  lists, checkboxes, code blocks, tables), using the markdown parsers that ship with Neovim. Its icons
  are set to symbols that need no Nerd Font.
- These features work in every Neovim instance, not only in MR windows (`MR_NAME`), because reading a
  proposal needs no Claude session.
- `<leader>mr` and the other MR review keys are unchanged.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `neovim-editor`: the pinned plugin set gains render-markdown.nvim, plus new requirements for markdown
  rendering, the OpenSpec change view and the delta spec diff.

## Impact

- `files/agentic-mr.lua`: new plugin spec, the view and diff functions, `:OpenSpecView`, and the
  `<leader>sv` / `<leader>sd` keys.
- `README.md`: plugin and key map tables.
- Hosts: one more plugin fetched on the next role run (the existing pin check covers it). `openspec`
  must be on `PATH` for the validation step; without it the view still opens, and a warning says
  validation was skipped.
- No new role variables and no change to `tasks/main.yml`.
