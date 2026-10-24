## Purpose

The role provisions Neovim as the coding editor, with the user's long-standing editing settings
and pinned plugins that tie each editor instance to the Claude Code session and the MR of its
git worktree.

## ADDED Requirements

### Requirement: Neovim installed
The role SHALL install Neovim with apt on Debian-family hosts and with Homebrew on macOS, and SHALL
fail when the installed Neovim is older than 0.10. It SHALL NOT install Vim.

#### Scenario: macOS host
- **WHEN** the role runs on `ricombam5`
- **THEN** `nvim --version` reports 0.10 or later, and the run is idempotent (`changed=0` on a second run)

### Requirement: Settings carried over from vimrc
`~/.config/nvim/init.lua` SHALL reproduce the previous `vimrc` behaviour: UTF-8, line numbers,
cursorline, `showmatch`, `scrolloff=5`, 2-space expanded indent with 4 for Python, fold method per
filetype (syntax for sh/terraform/cpp/go, indent for yaml/python) with `foldlevelstart=99`,
removal of trailing whitespace on write, `.py` suffix, 500-line history, wildmenu, `ack` grepprg,
arrow keys disabled, `hlsearch`/`incsearch` and visual bell.

#### Scenario: Python buffer
- **WHEN** a `.py` file is opened
- **THEN** `shiftwidth` is 4, `foldmethod` is `indent`, and every fold is open

#### Scenario: Trailing whitespace
- **WHEN** a buffer with trailing spaces is written
- **THEN** the written file has none

### Requirement: Colorscheme
Neovim SHALL use the `wombat256` colorscheme with its 256-colour palette, as Vim did, even when
the terminal supports truecolor.

#### Scenario: Truecolor terminal
- **WHEN** Neovim starts in a terminal that advertises truecolor
- **THEN** `termguicolors` is off and `Normal` uses background colour 234

### Requirement: Pinned plugins
The plugin set SHALL be lazy.nvim with claudecode.nvim, opencode.nvim, diffview.nvim,
gitsigns.nvim, octo.nvim, snacks.nvim, plenary.nvim and vim-surround, each pinned to a commit
(tags can be force-moved). At deploy time, whenever the plugin spec changed, the role SHALL bring
every plugin to its pinned commit, and SHALL fail the run when a plugin is missing or off its pin.
Neovim SHALL never download plugins at startup.

#### Scenario: Fresh host
- **WHEN** the role has run and `nvim` starts for the first time
- **THEN** no plugin is downloaded at startup and `:checkhealth lazy` reports no error

#### Scenario: Pin bumped
- **WHEN** a plugin's commit is changed in the spec and the role reruns
- **THEN** that plugin is checked out at the new commit on the host

#### Scenario: Plugin cannot be fetched
- **WHEN** a plugin cannot be cloned, or lazy.nvim itself cannot be bootstrapped, during the role run
- **THEN** the run fails instead of reporting success

### Requirement: Per-worktree agent bridge
Each Neovim instance opened by `mr` (`MR_NAME` set) SHALL run the claudecode.nvim server with no
embedded terminal, so a `claude --ide` started in the same directory attaches to that instance.
Other Neovim instances SHALL NOT run it. Key maps:
`<leader>as` (send selection), `<leader>ab` (add buffer), `<leader>aa` / `<leader>ad`
(accept / deny the proposed diff).

#### Scenario: Editor outside an MR window
- **WHEN** Neovim starts without `MR_NAME` (a git commit editor, nvim in `~`)
- **THEN** no `~/.claude/ide/*.lock` file is written for it

#### Scenario: Two worktrees
- **WHEN** two Neovim instances run in two worktrees and `claude --ide` starts in the second one
- **THEN** that session attaches to the second Neovim only

### Requirement: MR review maps
`<leader>mr` SHALL open diffview on `$(mr-base)...HEAD`, falling back to `origin/HEAD...HEAD` when
`mr-base` is unavailable. `<leader>mu`, `<leader>mh` and `<leader>mq` SHALL open the uncommitted
changes, open the file history, and close the review. `<leader>mp` / `<leader>mR` SHALL list PRs
and start a PR review through octo. `<leader>ml` / `<leader>mw` SHALL show `mr ls -p` and switch
to another MR's window.

#### Scenario: Stacked MR review
- **WHEN** `<leader>mr` is pressed on a branch whose `mrbase` is `feat/a`
- **THEN** diffview shows only the commits on top of `feat/a`

### Requirement: Legacy Vim setup removed
The role SHALL remove the files it previously managed: `~/.vimrc`,
`~/.vim/pack/tpope/start/{surround,commentary}`, `~/.vim/pack/pasky/start/claude.vim` and
`~/.vim/colors/wombat256.vim`, and nothing else under `~/.vim`. It SHALL NOT accept or write an Anthropic
API key.

#### Scenario: Upgrade from the Vim role
- **WHEN** the role runs on a host provisioned by the previous version
- **THEN** `~/.vimrc` and `~/.vim/pack/pasky/start/claude.vim` no longer exist, and no file the role manages contains an API key
