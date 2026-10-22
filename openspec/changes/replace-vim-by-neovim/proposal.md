# Proposal

## Why

The parallel-MR workflow (`~/.claude` change `worktree-per-mr`) runs one editor per git worktree,
bridged to that worktree's Claude Code session. That bridge (claudecode.nvim), the MR review
(diffview.nvim) and PR threads (octo.nvim) exist for Neovim only. The role today installs Vim with
`claude.vim`, which needs a raw Anthropic API key, and it writes that key into `~/.vimrc` with
mode `0755`.

## What Changes

- **BREAKING**: the role installs and configures **Neovim** instead of Vim: apt `neovim` on
  Debian, Homebrew `neovim` on macOS. It no longer installs or configures Vim.
- New `~/.config/nvim/init.lua`: a port of every current `vimrc` setting (encoding, 2-space
  indent with Python at 4, fold methods per filetype with `foldlevelstart=99`, trailing-space
  strip on write, `ack` as grepprg, arrow keys disabled, search highlighting, wildmenu, the
  `wombat256` colorscheme), plus a lazy.nvim bootstrap.
- New `~/.config/nvim/lua/plugins/agentic-mr.lua` (from the multi-MR kit), every plugin pinned:
  claudecode.nvim (the IDE bridge for `claude --ide`), opencode.nvim, diffview.nvim (`<leader>mr`
  = diff against `mr-base`), gitsigns.nvim, octo.nvim (PR threads), snacks.nvim, plenary.nvim.
- `vim-surround` moves to lazy.nvim. `vim-commentary` is dropped: Neovim ≥ 0.10 ships `gc`
  commenting.
- **BREAKING**: `claude.vim` and the `vim_anthropic_key` variable are removed. The role deletes
  exactly the files it used to manage (`~/.vimrc`, `~/.vim/pack/tpope/start/{surround,commentary}`,
  `~/.vim/pack/pasky/start/claude.vim`, `~/.vim/colors/wombat256.vim`), which fixes the
  world-readable key.
- Plugins are synced to their pinned commits at deploy time (`Lazy! sync`, then a pin check that
  fails the run), so the first editor launch in a fresh worktree does not stall.
- README documents the key maps and the `mr` integration.

## Capabilities

### New Capabilities

- `neovim-editor`: what the role installs and configures for the editor: the package, the
  settings, the pinned plugins and their key maps, and the removal of the legacy Vim setup.

### Modified Capabilities

None. `openspec/specs/` is empty.

## Impact

- Files: `tasks/main.yml`, `meta/main.yml`, `README.md`,
  `files/init.lua`, `files/agentic-mr.lua`, `files/lazy-check.lua` (new, static, so copied rather than templated),
  `templates/vimrc.j2` and `defaults/main.yml` (removed: the role has no variables left),
  `templates/wombat256.j2` (kept, deployed under `~/.config/nvim/colors/`).
- Consumer: `mymac` (`roles/vim` submodule), bumped after merge. Its playbook passes no
  `vim_anthropic_key`, so nothing breaks there.
- `<leader>mr` calls `mr-base`, and `<leader>ml` / `<leader>mw` call `mr`, from the `~/.claude`
  change. Without them, `<leader>mr` falls back to `origin/HEAD`.
- `octo.nvim` needs an authenticated `gh` (present on `ricombam5`).
