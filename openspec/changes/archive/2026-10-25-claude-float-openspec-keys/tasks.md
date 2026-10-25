# Tasks

## 1. Plugin spec

- [x] 1.1 `files/agentic-mr.lua`: claudecode.nvim with `provider = "snacks"`, a `cwd_provider` on the git root of Neovim's cwd, `term_normal = false`, `focus_after_send`, float 0.9 x 0.9 rounded, terminal-mode `<M-,>` hide key, `diff_opts.open_in_new_tab` + `hide_terminal_in_new_tab`. Keys `<M-,>` (n, x), `<leader>aC`, `<leader>ar`, plus the existing four. Pin, `cond` and `lazy = false` kept. Header comment updated. Verify with a headless `MR_NAME=t nvim` loading this file: setup raises no config assert, and `maparg('<M-,>','n')` is set
- [x] 1.2 Same file: OpenSpec keys `<leader>se/sp/sa/sA/so` through `send_to_terminal(text, { submit, focus = true })` and a snacks file picker on `openspec/changes`. Verify the headless check lists all five maps, and `<leader>sa` with no float logs the plugin's "no Claude terminal" warning
- [x] 1.3 Same file: `<leader>mr` opens `DiffviewOpen <merge-base of mr-base and HEAD>`, with `origin/HEAD` fallback. Verify in a scratch repo with one committed and one uncommitted change on top of the base that both appear (`:DiffviewOpen` file panel)

## 2. Docs and lint

- [x] 2.1 `README.md`: key table (float, `aC`/`ar`, OpenSpec row, new `<leader>mr` range), the Option-as-Alt note for macOS terminals, and `/bg` before quitting. Intro no longer says the agent is always in the right pane. Verify by reading and by a grep for host names and absolute home paths (public repo)
- [x] 2.2 `ansible-lint` (production profile) clean. `luac -p` or `nvim --headless -l` parses `files/agentic-mr.lua`

## 3. Apply on a macOS host

- [x] 3.1 Run the role from this checkout against localhost (`--start-at-task "Read the neovim version"` while the homebrew task fails on already-installed formulae), then once more: second run `changed=0`, pin check passes
- [x] 3.2 Smoke test in a tmux window with `MR_NAME` set: `Alt+,` shows Claude in a float at the worktree root and hides it again; `<leader>sp` leaves `/opsx:propose ` on the prompt; a proposed edit opens in a new tab

## Workflow follow-up

- After merge: bump `roles/vim` in `mymac` and rerun `--tags vim` on both Macs.
- The archive is automatic (`openspec-archive.yml`) after merge.
