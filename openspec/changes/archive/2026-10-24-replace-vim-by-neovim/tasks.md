# Tasks

## 1. Role

- [x] 1.1 `tasks/main.yml`: install `neovim` (apt on Debian, `community.general.homebrew` on Darwin), create `~/.config/nvim/{lua/plugins,colors}`, copy `files/init.lua`, `files/agentic-mr.lua`, template `colors/wombat256.vim` (mode 0644), a pin check on every run (`lazy-check.lua`, no network) and `Lazy! sync` + the check only when it fails; drop the vim, surround, commentary and claude.vim tasks; verify `ansible-lint` (production profile) is clean
- [x] 1.2 Legacy cleanup task: `state: absent` on `~/.vimrc`, `~/.vim/pack/tpope`, `~/.vim/pack/pasky`, `~/.vim/colors/wombat256.vim`; verify by reading and through lint
- [x] 1.3 remove `defaults/main.yml` (its only variable was `vim_anthropic_key`); `meta/main.yml`: description mentions Neovim; verify `ansible-lint`

## 2. Neovim config

- [x] 2.1 `files/init.lua`: port every vimrc setting listed in the spec plus the lazy.nvim bootstrap (pinned commit, fails cleanly, `install.missing = false`, luarocks off); verify `nvim --headless -u <rendered init.lua> +qa` exits 0 and `:set sw? fdm?` on a `.py` buffer prints 4 / indent
- [x] 2.2 `files/agentic-mr.lua`: the kit spec plus `tpope/vim-surround`, each plugin pinned to a commit (the latest tag's commit, or HEAD where the project has no recent tags), resolved with `git ls-remote`; `mr_tool` returns nil when not executable; `mr-base` / `mr` called by absolute path with a `PATH` fallback; verify `:checkhealth lazy` and `:Lazy` show every plugin installed at its pin
- [x] 2.3 Remove `templates/vimrc.j2`; README: Neovim, plugin list, key maps, the `mr` integration, the removed variable; verify by reading

## 3. Apply on ricombam5

- [x] 3.1 Move `~/.vimrc` to `~/.vimrc.bak-20261022` (chmod 0600); run the role from this checkout against localhost with `--check`, then for real, then once more and confirm `changed=0`
- [x] 3.2 Smoke test: `nvim` in a worktree created by `mr new`; `:ClaudeCodeStatus` shows the server, and `claude --ide` in the right pane attaches; `<leader>mr` opens diffview against `mr-base`

## Workflow follow-up

- After merge: bump the `roles/vim` submodule in `mymac`; consider adding `neovim` and `tmux` to its `homebrew_installed_packages`.
- After merge: archive in its own MR, `mr new chore/archive-replace-vim-by-neovim --prompt "/opsx:archive replace-vim-by-neovim"`.
- Rotate the old Anthropic API key that `claude.vim` used.
