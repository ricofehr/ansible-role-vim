# Tasks

## 1. Markdown rendering

- [x] 1.1 Add render-markdown.nvim to `files/agentic-mr.lua`, pinned at `640a3ec6d538bad17c328be373c7cad0293d9589` (v8.14.0), `ft = "markdown"`, with plain-Unicode heading, checkbox and code-sign settings, and rendering off in diff windows. Verify: `nvim --headless "+luafile ~/.config/nvim/lazy-check.lua"` exits 0 after `Lazy! sync` on a local copy
- [x] 1.2 Open this change's `proposal.md` and a diffview buffer on a macOS host. Verify headings, bullets and checkboxes render with no missing-glyph boxes, the cursor line shows raw text, `:RenderMarkdown toggle` works, and the diff window is not concealed
- [x] 1.3 Add render-markdown.nvim to the README plugin table. Verify the table lists every plugin in the spec

## 2. OpenSpec change view

- [x] 2.1 Implement root and active-change resolution (git toplevel, `openspec/changes/*` minus `archive`) and `:OpenSpecView [change]` with completion, created in the render-markdown spec's `config` and lazy-loaded through `cmd`. Verify `:OpenSpecView <Tab>` lists `openspec-proposal-view` in this worktree
- [x] 2.2 Open the tab: `tabnew` + `arglocal` with the existing artifacts in order proposal, sorted delta specs, design, tasks. Add the `<leader>sv` key. Verify on this change that the tab shows `proposal.md`, `]a` walks to `specs/neovim-editor/spec.md`, then design, then tasks, and `:args` in the first tab is unchanged
- [x] 2.3 Handle the edge cases: a picker with two active changes (use a scratch second change in a temp copy), a warning with no change, and no file created for a missing artifact. Verify each spec scenario by hand
- [x] 2.4 Run `openspec validate <change> --strict --json` asynchronously and send the INFO / ERROR / WARN notifications. Verify: valid change → INFO; a temp copy with a scenario-less requirement → ERROR listing the finding; `PATH` without `openspec` → WARN, and the tab still opens
- [x] 2.5 Document `:OpenSpecView` / `<leader>sv` in the README (OpenSpec row, plus a note that it works outside MR windows). Verify the README key list matches the keys in the spec

## 3. Delta spec diff

- [x] 3.1 Implement `<leader>sd`: match the buffer against `openspec/changes/<change>/specs/<capability>/spec.md`, open a tab with the main spec on the left and the delta on the right, `diffthis` both, open the delta alone with a notice for a new capability, and warn elsewhere. Verify on this change's `neovim-editor` delta (diff shows the added `render-markdown.nvim` in *Pinned plugins*), on a scratch delta for a new capability, and from `proposal.md`
- [x] 3.2 Document `<leader>sd` in the README, including that ADDED blocks show as pure additions. Verify the README entry

## 4. Role integration

- [x] 4.1 Run the role on a macOS host twice. Verify the first run syncs the new plugin and the second reports `changed=0`, and `:checkhealth lazy` shows no error
- [x] 4.2 Run `ansible-lint` at the repo's profile. Verify it passes
- [x] 4.3 Check that `<leader>mr`, `<leader>so` and the `/opsx:*` send keys still behave as before in an MR window

## Workflow follow-up

- Archive happens after merge through `.github/workflows/openspec-archive.yml`.
