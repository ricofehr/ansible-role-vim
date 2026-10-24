# Design

## Context

- The role is consumed by `mymac` as the `roles/vim` submodule, with Homebrew already on `PATH`
  (`geerlingguy.mac.homebrew` runs first). It installs nothing on macOS today. Neovim 0.12.6 is
  on `ricombam5` through a manual `brew install`.
- The kit's lazy.nvim spec (`multi-mr-kit/nvim/lua/plugins/agentic-mr.lua`) assumes an existing
  lazy.nvim setup. There is none, so the role owns the bootstrap.
- The role pins git plugins by tag or commit (`vim-surround` v2.2, `commentary` 64a654e). The
  same rule carries over.
- `ansible-lint` runs at the `production` profile, in CI (`ansible/ansible-lint@v25.2.1`) and
  locally.

## Goals / Non-Goals

**Goals:** a deterministic, idempotent Neovim install; settings parity with the old vimrc; the
MR-cockpit plugins.

**Non-Goals:** aliasing `vim` → `nvim` or setting `EDITOR` (shell and gitconfig concerns, not
the editor role's); LSP, treesitter or completion plugins; adding `neovim` / `tmux` to `mymac`'s
Homebrew list (a follow-up in that repo); renaming the role or the repository.

## Decisions

1. **Plain lazy.nvim, no distribution (LazyVim and the like).** A distribution would replace the
   user's settings with its own defaults. `init.lua` stays a direct port.
2. **Pins are commits, in the spec, not a templated `lazy-lock.json`.** The versions show in the
   reviewed file, as the old role pinned plugins, and nothing rewrites a lock file behind the
   user's back. They are commit SHAs, with the release tag as a comment, because tags can be
   force-moved and `Lazy! sync` follows them. lazy.nvim itself is cloned and checked out at the
   same commit by the `init.lua` bootstrap, which stops cleanly (no plugins, colorscheme kept)
   when the clone fails. `install.missing = false` means Neovim never downloads at startup.
3. **Check every run, sync only on drift.** `lazy-check.lua` quits non-zero unless every
   plugin is installed on its pinned commit; it needs no network and runs on each role run
   (`changed_when: false`). Only when it fails does the role run `Lazy! sync` (install, move
   each plugin to its pin, remove dropped ones — `Lazy! install` would not move an installed
   plugin) followed by the same check, failing the run on any drift; a trailing `cquit 1`
   covers a failed bootstrap. Alternative rejected: a handler notified by the Lua files — a
   failed sync consumes the notification and is never retried, and a later role failing in
   `mymac` drops it.
4. **Keep the colorscheme as Vim script.** `wombat256.vim` loads unchanged in Neovim and lands in
   `~/.config/nvim/colors/`.
5. **Remove only what the old role created**, plugin by plugin. `~/.vim`, `.netrwhist` and any
   hand-added plugin stay. On
   `ricombam5` the live `~/.vimrc` holds the key and has no other copy, so before the first run it
   moves to `~/.vimrc.bak-20261022` (mode 0600), a manual step outside the role.
6. **The IDE server runs only in `mr` windows** (`cond` on `MR_NAME`), and `termguicolors` is
   off so `wombat256` keeps Vim's 256-colour palette.
7. **Leader stays the default `\`.** The old `claude.vim` maps used `<Leader>` with the default
   leader, so muscle memory is kept.

## Risks / Trade-offs

- [The deploy-time plugin sync needs network] → The run fails, and the next run retries, because the check fails again.
- [Ubuntu's apt `neovim` older than the plugins' minimum (24.04 ships 0.9.5, Debian 12 0.7.2)] →
  The role asserts ≥ 0.10 right after installing and fails with the version found. Ubuntu 26.04
  ships a recent enough one.
- [The old Anthropic key was readable by group `staff`] → Recommend rotating it in the Anthropic
  console. The role stops writing it.

## Migration Plan

1. On `ricombam5`: back up `~/.vimrc` (0600), then run the branch's role against localhost (check
   mode, then for real), then rerun to confirm idempotence.
2. After merge: bump the `mymac` submodule.
3. Rollback: check out the previous role version and rerun. It recreates `~/.vimrc` (with the
   placeholder key).
