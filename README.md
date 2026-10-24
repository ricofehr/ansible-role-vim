# ansible-role-vim

Installs **Neovim** (apt on Debian, Homebrew on macOS) and its config for agentic coding:
one Neovim per git worktree, bridged to the Claude Code (or opencode) session running next to it.
It pairs with the `mr` launcher from
[claude-user-settings](https://github.com/ricofehr/claude-user-settings), which opens each MR in
its own tmux window: Neovim on the left, the agent on the right.

The role used to install Vim with `claude.vim`. It now removes what that version managed
(`~/.vimrc`, `~/.vim/pack/tpope/start/{surround,commentary}`, `~/.vim/pack/pasky/start/claude.vim`,
`~/.vim/colors/wombat256.vim`). It needs Neovim 0.10 or later and fails on older ones. The
`vim_anthropic_key` variable is gone, and the role takes no variables.

## What it writes

| Path | Contents |
|---|---|
| `~/.config/nvim/init.lua` | The former vimrc settings (2-space indent, 4 for Python; fold method per filetype, all folds open; trailing whitespace stripped on write; `ack` as grepprg; arrow keys disabled) plus the lazy.nvim bootstrap |
| `~/.config/nvim/lua/plugins/agentic-mr.lua` | The plugins, each pinned to a commit |
| `~/.config/nvim/lazy-check.lua` | The pin check the role runs |
| `~/.config/nvim/colors/wombat256.vim` | The colorscheme |

Every plugin is pinned to a commit (its release tag in a comment).
Every role run checks them with `lazy-check.lua` (no network). Only when a plugin is missing or
off its pin does it run `Lazy! sync`, then the check again, which fails the run on any drift, so
a sync that failed offline is retried on the next run. Neovim itself never downloads plugins at
startup. To upgrade a plugin, bump its `commit` in `files/agentic-mr.lua` (lazy.nvim's also in
`files/init.lua`), then rerun the role.

## Plugins and key maps

Leader is the default `\`.

| Plugin | Keys | Does |
|---|---|---|
| [claudecode.nvim](https://github.com/coder/claudecode.nvim) | `<leader>as` (visual) send selection · `<leader>ab` add buffer · `<leader>aa` / `<leader>ad` accept / deny diff | IDE bridge: `claude --ide` started in the same directory attaches to this Neovim. Only in windows opened by `mr` (`MR_NAME` set) |
| [opencode.nvim](https://github.com/nickjvandyke/opencode.nvim) | `<leader>oa` ask · `<leader>os` actions | Same, for an opencode session in this directory |
| [diffview.nvim](https://github.com/sindrets/diffview.nvim) | `<leader>mr` MR vs its base (`mr-base`) · `<leader>mu` uncommitted · `<leader>mh` file history · `<leader>mq` close | Review the MR's real diff, stacked MRs included |
| [octo.nvim](https://github.com/pwntester/octo.nvim) | `<leader>mp` PR list · `<leader>mR` start PR review | PR threads from the editor (needs an authenticated `gh`) |
| [snacks.nvim](https://github.com/folke/snacks.nvim) | `<leader>ml` `mr ls -p` board · `<leader>mw` switch MR window | Cockpit helpers |
| [gitsigns.nvim](https://github.com/lewis6991/gitsigns.nvim), [vim-surround](https://github.com/tpope/vim-surround), plenary.nvim | | Hunks in the sign column; surround; octo dependency |

Commenting (`gc`) is built into Neovim ≥ 0.10. Without `mr-base` on `PATH` or in
`~/.claude/bin/`, `<leader>mr` diffs against `origin/HEAD`.
