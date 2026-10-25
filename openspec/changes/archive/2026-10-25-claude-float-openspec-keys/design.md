# Design

## Context

`files/agentic-mr.lua` configures claudecode.nvim with `terminal = { provider = "none" }`: the
server runs, and Claude lives in the tmux pane to the right, started by `mr` as `claude --ide`.
Every option this change uses exists at the pinned commit `2390c6e` (`cwd_provider` with `cwd.git_root`,
`focus_after_send`, `terminal.snacks_win_opts`, `diff_opts.open_in_new_tab`,
`diff_opts.hide_terminal_in_new_tab`, `terminal.send_to_terminal(text, { submit, focus })`).

## Goals / Non-Goals

**Goals:** Claude reachable from inside Neovim without a split. OpenSpec commands one key away.
The split layout keeps working.

**Non-Goals:** Changing `mr` (separate change in `claude-user-settings`). Configuring the
terminal's Option key. Bumping plugin pins.

## Decisions

- **Snacks provider, explicit.** Set `terminal.provider = "snacks"` rather than leaving `"auto"`:
  snacks.nvim is already a pinned dependency, and the float options are snacks window options.
- **Keep `cond = MR_NAME` and `lazy = false`.** The source doc dropped them. Dropping the guard would let a
  commit editor advertise a workspace. The server must start with Neovim so `claude --ide` in a
  split pane can still attach.
- **Send through `send_to_terminal(..., { focus = true })`, not `:ClaudeCodeFocus` after sending.**
  `ClaudeCodeFocus` toggles, so it hides a float that is already focused. The plugin's `focus` option
  opens it instead. Starting a session and sending to it is left to the user (press `Alt+,` first),
  because text sent before Claude's prompt is ready is lost. The plugin's warning covers the empty case.
- **`<leader>s` prefix for OpenSpec.** `<leader>o` belongs to opencode (`oa`, `os`). The user chose
  to keep it there.
- **`<leader>mr` instead of a new `<leader>gm`.** A second key for the same diff would be redundant. Diffview
  given a single rev compares it with the working tree. The merge-base is computed with
  `git merge-base <base> HEAD` so a moving base still gives the fork point. On failure, fall back to the
  base itself.
- **Terminal-mode hide key in `snacks_win_opts.keys`.** `<M-,>` is mapped in mode `t` on the float window
  only. snacks' own `term_normal` (double `Esc` to normal mode) is turned off, so `Esc` is never captured.
- **`cwd_provider` rather than `git_repo_cwd`.** `git_repo_cwd` starts from the current buffer's
  directory, so a file from another repo or a sibling worktree would start Claude there. The provider
  takes the git root of Neovim's cwd, which `mr` sets to the worktree.

## Risks / Trade-offs

- [The float is a child of Neovim: quitting Neovim ends the session] → README notes `/bg` before quitting,
  and `<leader>aC` to come back.
- [`Alt+,` arrives as `≤` on macOS terminals without Option-as-Alt] → README documents the Ghostty
  setting. The keys still work through `:ClaudeCodeFocus`.
- [Saving a diff buffer accepts the edit] → Same behaviour as today. No auto-save plugin is installed.

## Migration Plan

Merge, bump the `roles/vim` submodule in `mymac`, rerun the role (`--tags vim`) on each host. No
pin changes, so the run only rewrites `agentic-mr.lua`. Roll back by reverting the commit and rerunning.
