# Design

## Context

All plugin specs and the agentic helpers live in `files/agentic-mr.lua`, which the role copies to
`~/.config/nvim/lua/plugins/`. The OpenSpec keys sit in the claudecode.nvim spec, which only loads with
`MR_NAME` set (`cond`). That includes `<leader>so`, a snacks file picker on `openspec/changes/`.
Neovim 0.10+ (the role's floor) ships the `markdown` and `markdown_inline` tree-sitter parsers.
The hosts run 0.11.6 (apt) and 0.12.6 (Homebrew). There is no nvim-treesitter and no icon plugin.
diffview runs with `use_icons = false`. `termguicolors` is off (wombat256, 256 colours).

## Goals / Non-Goals

**Goals:**
- Read a whole change, rendered, in one tab, without leaving the MR window's Neovim.
- Keep the role's contract: every plugin pinned, no network at startup, no new role variable or task.

**Non-Goals:**
- Editing or confirming the proposal from Neovim. Confirmation stays a message to the agent.
- A structured "requirement by requirement" delta view. A line diff is enough for now.
- Untracked files in `<leader>mr` (left unchanged on purpose).

## Decisions

**render-markdown.nvim v8.14.0 (`640a3ec6d538bad17c328be373c7cad0293d9589`), `ft = "markdown"`.**
It renders inside the buffer with extmarks and uses the bundled parsers, so there is no external
viewer process. Alternatives:
- Glow or `markdown-preview.nvim`: a separate window or a browser, and an external binary or a Node build.
- `openspec show` in a float: plain text, one artifact, not navigable.

Its default icons are Nerd Font glyphs. They are overridden with plain Unicode: `#` levels for headings,
`☐` / `☑` / `◐` for checkboxes, no code sign or language icon, callout labels without their glyph. Link icons
are turned off (`link.enabled = false`), since every link type and domain has its own glyph. LaTeX
handling is off too, so buffer text is never piped to an external converter. That matches
the no-devicons choice made for diffview.

**The view and diff code goes into `agentic-mr.lua`, outside the claudecode spec.** The keys and the
command hang off the render-markdown spec (`keys`, `cmd = "OpenSpecView"`), so they exist in every Neovim
and loading them loads the renderer the view needs. The command itself is created in that spec's
`config`. Alternative: a separate `lua/openspec_view.lua` module. That would mean a new copy task and
file for about 80 lines. Rule of three: not yet.

**Change resolution.** The root is `git rev-parse --show-toplevel` from `getcwd()`, falling back to
`getcwd()` itself. The view must work without the claudecode spec loaded, so claudecode is not a dependency;
`<leader>so` uses the same helper. `<leader>sd` takes the root from the buffer's directory instead, so it
works when Neovim started outside the repo. A `:OpenSpecView` argument must name an active change, and
directory names holding a control character are ignored: a crafted checkout can't inject a second Ex
command through a file name. Active changes are the
subdirectories of `openspec/changes/` except `archive`. With one change, it opens directly. With
several, `vim.ui.select` asks. No change at all gives a warning. Completion uses the same listing.

**Tab layout.** `tabnew`, then `arglocal` with the existing files in the order proposal,
`specs/**/spec.md` (sorted), design, tasks. `arglocal` keeps the user's global arglist intact, and
`]a` / `[a` (built in since 0.11) navigate. On 0.10, `:next` / `:prev` do the same. Alternative: a
split per artifact. That is unreadable on a laptop screen.

**Validation.** `vim.system({ "openspec", "validate", "--type", "change", "--strict", "--json",
"--no-interactive", "--", name }, { cwd = root })` runs asynchronously. `--type change` keeps a change named
like a capability from being ambiguous, and `--` keeps a name from being read as a flag. On exit, `vim.schedule` sends a notification: INFO when the change is valid, ERROR
listing each `items[].issues[]` entry (level, path, message) when it is not. When the output has no
`items`, the error shows openspec's `status[].message` (it prints errors as JSON on stdout), then raw
stdout and stderr. `openspec` is found with `vim.fn.executable`. When it is missing, a WARN is shown
and the tab still opens.

**Delta diff.** The buffer path is matched against `openspec/changes/<change>/specs/(.+)/spec.md`
under the root, which keeps nested capability paths. In a new tab: the main spec, `vsplit` on the delta,
then `diffthis` in both windows (structured `vim.cmd.diffsplit`, never a concatenated command string).
render-markdown keeps marks per buffer, so a delta also shown in the view tab would render in the diff
window. Rendering is paused for both buffers until the delta's diff window closes. Neovim's default `diffopt` includes `linematch` since 0.11, which
aligns the scenarios of a MODIFIED requirement line by line. With no main spec, only the delta opens,
with an INFO notice.

## Risks / Trade-offs

- [A delta is not a full spec, so ADDED blocks show as pure additions and the whole main spec shows as
  "removed" context] → expected. The useful signal is inside MODIFIED requirements. The README says so.
- [render-markdown changes how every markdown file looks, including the README and Claude's diff tabs]
  → raw text on the cursor line, and `:RenderMarkdown toggle` turns it off. In diff mode, concealment
  could hide real changes. The plugin's default `render.diff = false` already skips diff windows, and
  that was verified for a buffer opened by `diffsplit`.
- [Highlight groups under 256 colours may look flat with wombat256] → checked on a host during apply.
  Adjust with links to existing wombat groups if needed. This is cosmetic and does not block.
- [`openspec validate` takes a second or two on a cold Node start] → asynchronous, never blocks typing.

## Migration Plan

Merge, then rerun the role. The pin check finds render-markdown missing, runs `Lazy! sync` and re-checks.
Rollback: revert the commit and rerun the role. lazy.nvim cleans the unused plugin on the next sync.
