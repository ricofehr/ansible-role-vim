# ansible-role-vim

Installs **Neovim** (apt on Debian, Homebrew on macOS) and its config for agentic coding:
one Neovim per git worktree, bridged to its Claude Code (or opencode) session. Claude runs in a
float inside Neovim, or in a pane next to it. It pairs with the `mr` launcher from
[claude-user-settings](https://github.com/ricofehr/claude-user-settings), which opens each MR in
its own tmux window.

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
| [claudecode.nvim](https://github.com/coder/claudecode.nvim) | `Alt+,` open / focus / hide the Claude float · `<leader>aC` continue last session · `<leader>ar` pick a session · `<leader>as` (visual) send selection · `<leader>ab` add buffer · `<leader>aa` / `<leader>ad` accept / deny diff | IDE bridge: Claude in the float (90% of the screen, started at the worktree root), or `claude --ide` started in the same directory, attaches to this Neovim. When Claude asks before an edit, the edit opens as a diff in its own tab: `:w` or `<leader>aa` accepts, `:q` or `<leader>ad` rejects. In auto or accept-edits mode Claude edits directly, with no diff tab. Only in windows opened by `mr` (`MR_NAME` set) |
| OpenSpec (claudecode.nvim) | `<leader>se` explore · `<leader>sp` propose (type the name, then Enter) · `<leader>sa` apply · `<leader>sA` archive · `<leader>so` pick a file in the worktree's `openspec/changes/` | Sends the `/opsx:*` command to the Claude float and focuses it. Open the float with `Alt+,` first: with none running, nothing is sent and a warning says so |
| [opencode.nvim](https://github.com/nickjvandyke/opencode.nvim) | `<leader>oa` ask · `<leader>os` actions | Same, for an opencode session in this directory |
| [diffview.nvim](https://github.com/sindrets/diffview.nvim) | `<leader>mr` MR vs its base (`mr-base`), from the fork point to the working tree, uncommitted changes to tracked files included (new untracked files: `<leader>mu`) · `<leader>mu` uncommitted · `<leader>mh` file history · `<leader>mq` close | Review the MR's real diff, stacked MRs included |
| [octo.nvim](https://github.com/pwntester/octo.nvim) | `<leader>mp` PR list · `<leader>mR` start PR review | PR threads from the editor (needs an authenticated `gh`) |
| [snacks.nvim](https://github.com/folke/snacks.nvim) | `<leader>ml` `mr ls -p` board · `<leader>mw` switch MR window | Cockpit helpers |
| [gitsigns.nvim](https://github.com/lewis6991/gitsigns.nvim), [vim-surround](https://github.com/tpope/vim-surround), plenary.nvim | | Hunks in the sign column; surround; octo dependency |

The float is part of Neovim: quitting Neovim ends its Claude session. Move a running task to the
background with `/bg` first, and come back to an idle one with `<leader>aC`. `<leader>aC` and
`<leader>ar` only continue or pick a session when no float runs yet in this Neovim; with one running,
they show or hide it, like `Alt+,`. `Esc` stays with
Claude (interrupt); only `Alt+,` hides the float.

On macOS, `Alt+,` needs the terminal to send Option as Alt, or it arrives as `≤`. In Ghostty,
`macos-option-as-alt = left` keeps the right Option key for symbols. In iTerm2: *Profiles → Keys →
Left Option key: Esc+*. The role does not change terminal settings.

Commenting (`gc`) is built into Neovim ≥ 0.10. Without `mr-base` on `PATH` or in
`~/.claude/bin/`, `<leader>mr` diffs against `origin/HEAD`.
