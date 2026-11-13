-- Managed by ansible-role-vim. Agentic multi-MR workflow (lazy.nvim spec).
-- One Neovim per git worktree, started by `mr` in that MR's tmux window. Claude
-- runs in a float inside it (Alt+,), or in a pane beside it when `mr` splits the window.
-- Every plugin is pinned to a commit (tags can be force-moved): bump the commit
-- here, then rerun the role: it syncs and checks every pin.

-- Absolute path of an `mr` script, or nil when it is not installed.
local function mr_tool(name)
  local path = vim.fn.exepath(name)
  if path == "" then
    path = vim.fn.expand("~/.claude/bin/" .. name)
  end
  if vim.fn.executable(path) == 1 then
    return path
  end
end

local function mr_base()
  local tool = mr_tool("mr-base")
  if not tool then
    return "origin/HEAD"
  end
  local out = vim.fn.systemlist({ tool })
  if vim.v.shell_error ~= 0 or not out[1] then
    return "origin/HEAD"
  end
  return out[1]
end

-- Fork point of the MR with its base, so a review covers exactly this MR's changes.
local function mr_fork_point()
  local base = mr_base()
  local out = vim.fn.systemlist({ "git", "merge-base", base, "HEAD" })
  if vim.v.shell_error ~= 0 or not out[1] then
    return base
  end
  return out[1]
end

-- Types text on the Claude float's prompt (submitted or not) and focuses the float.
-- Sends nothing, with the plugin's warning, while no float runs in this Neovim.
local function claude_send(text, submit)
  require("claudecode.terminal").send_to_terminal(text, { submit = submit, focus = true })
end

-- Git root of a directory (Neovim's cwd by default, the worktree Claude starts in), else the
-- directory itself. Plain git: the OpenSpec view must not need claudecode loaded.
local function git_root(dir)
  dir = dir or vim.fn.getcwd()
  local out = vim.fn.systemlist({ "git", "-C", dir, "rev-parse", "--show-toplevel" })
  if vim.v.shell_error == 0 and out[1] then
    return out[1]
  end
  return dir
end

-- Picker on the worktree's openspec/changes/.
local function pick_openspec_change()
  local root = git_root()
  local changes = root .. "/openspec/changes"
  if vim.fn.isdirectory(changes) == 0 then
    vim.notify("no openspec/changes in " .. root, vim.log.levels.WARN)
    return
  end
  Snacks.picker.files({ cwd = changes })
end

local function openspec_changes(root)
  local names = {}
  for name, kind in vim.fs.dir(root .. "/openspec/changes") do
    -- A control character (a newline from a crafted checkout) never reaches a command line.
    if kind == "directory" and name ~= "archive" and not name:find("%c") then
      table.insert(names, name)
    end
  end
  table.sort(names)
  return names
end

-- openspec prints its own errors as JSON on stdout (status[].message); stderr is the last resort.
local function validation_error(report, result)
  if type(report) == "table" and type(report.status) == "table" then
    local messages = vim.tbl_map(function(entry) return tostring(entry.message) end, report.status)
    if #messages > 0 then
      return table.concat(messages, "\n")
    end
  end
  return vim.trim((result.stdout or "") .. "\n" .. (result.stderr or ""))
end

local function validate_openspec_change(root, name)
  if vim.fn.executable("openspec") == 0 then
    vim.notify("openspec is not on PATH: validation skipped", vim.log.levels.WARN)
    return
  end
  -- --type: a change named like a capability is not ambiguous. --: a name is never read as a flag.
  local cmd = { "openspec", "validate", "--type", "change", "--strict", "--json", "--no-interactive", "--", name }
  vim.system(cmd, { cwd = root, text = true }, function(result)
    vim.schedule(function()
      local ok, report = pcall(vim.json.decode, result.stdout or "")
      report = ok and report or nil
      local item = type(report) == "table" and type(report.items) == "table" and report.items[1]
      if not item then
        local message = "openspec validate " .. name .. " failed:\n" .. validation_error(report, result)
        vim.notify(message, vim.log.levels.ERROR)
      elseif item.valid then
        vim.notify(name .. ": valid (openspec validate --strict)", vim.log.levels.INFO)
      else
        local lines = { name .. ": invalid (openspec validate --strict)" }
        for _, issue in ipairs(item.issues or {}) do
          local finding = ("%s %s: %s"):format(tostring(issue.level), tostring(issue.path), tostring(issue.message))
          table.insert(lines, finding)
        end
        vim.notify(table.concat(lines, "\n"), vim.log.levels.ERROR)
      end
    end)
  end)
end

-- A change in its own tab, artifacts in reading order on a window-local arglist (]a / [a).
local function open_openspec_change(root, name)
  local dir = root .. "/openspec/changes/" .. name
  local files = {}
  local function add_existing(path)
    if vim.uv.fs_stat(path) then
      table.insert(files, path)
    end
  end
  add_existing(dir .. "/proposal.md")
  local specs = vim.fn.globpath(dir .. "/specs", "**/spec.md", false, true)
  table.sort(specs)
  vim.list_extend(files, specs)
  add_existing(dir .. "/design.md")
  add_existing(dir .. "/tasks.md")
  if #files == 0 then
    vim.notify("no OpenSpec artifact in " .. dir, vim.log.levels.WARN)
    return
  end
  vim.cmd.tabnew()
  vim.cmd.arglocal({ args = vim.tbl_map(vim.fn.fnameescape, files) })
  validate_openspec_change(root, name)
end

local function openspec_view(opts)
  local root = git_root()
  local names = openspec_changes(root)
  if opts.args ~= "" then
    if vim.tbl_contains(names, opts.args) then
      open_openspec_change(root, opts.args)
    else
      vim.notify("not an active OpenSpec change: " .. opts.args, vim.log.levels.WARN)
    end
    return
  end
  if #names == 0 then
    vim.notify("no active OpenSpec change in " .. root, vim.log.levels.WARN)
  elseif #names == 1 then
    open_openspec_change(root, names[1])
  else
    vim.ui.select(names, { prompt = "OpenSpec change" }, function(choice)
      if choice then
        open_openspec_change(root, choice)
      end
    end)
  end
end

-- render-markdown keeps its marks per buffer, so a buffer shown in another tab too would render in
-- the diff windows: rendering stays off for these buffers until the window closes.
local function pause_markdown_render(bufs, win)
  local render = require("render-markdown")
  for _, buf in ipairs(bufs) do
    vim.api.nvim_buf_call(buf, render.buf_disable)
  end
  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(win),
    once = true,
    callback = function()
      for _, buf in ipairs(bufs) do
        if vim.api.nvim_buf_is_valid(buf) then
          vim.api.nvim_buf_call(buf, render.buf_enable)
        end
      end
    end,
  })
end

-- Main spec (left) against the delta spec in the current buffer (right), in a new tab.
local function openspec_delta_diff()
  local path = vim.uv.fs_realpath(vim.api.nvim_buf_get_name(0)) or ""
  local root = git_root(vim.fs.dirname(path))
  local prefix = root .. "/openspec/changes/"
  local capability = vim.startswith(path, prefix) and path:sub(#prefix + 1):match("^[^/]+/specs/(.+)/spec%.md$")
  if not capability or capability:find("%c") then
    local expected = "openspec/changes/<change>/specs/<capability>/spec.md"
    vim.notify("not an OpenSpec delta spec (" .. expected .. ")", vim.log.levels.WARN)
    return
  end
  local main = root .. "/openspec/specs/" .. capability .. "/spec.md"
  vim.cmd.tabedit(vim.fn.fnameescape(path))
  if not vim.uv.fs_stat(main) then
    vim.notify("new capability " .. capability .. ": no main spec to diff against", vim.log.levels.INFO)
    return
  end
  local delta_win, delta_buf = vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()
  vim.cmd.diffthis()
  -- Structured call: a file name can never start a second Ex command.
  vim.cmd.diffsplit({ args = { vim.fn.fnameescape(main) }, mods = { vertical = true, split = "aboveleft" } })
  pause_markdown_render({ delta_buf, vim.api.nvim_get_current_buf() }, delta_win)
end

-- Callout labels without their Nerd Font glyph ("[!NOTE]" renders as "Note").
local function plain_callouts()
  local callouts = {}
  for _, name in ipairs({
    "note", "tip", "important", "warning", "caution", "abstract", "summary", "tldr", "info", "todo",
    "hint", "success", "check", "done", "question", "help", "faq", "attention", "failure", "fail",
    "missing", "danger", "error", "bug", "example", "quote", "cite",
  }) do
    callouts[name] = { rendered = name:sub(1, 1):upper() .. name:sub(2) }
  end
  return callouts
end

local function pick_worktree()
  local mr = mr_tool("mr")
  if not mr then
    vim.notify("mr is not installed (~/.claude/bin/mr)", vim.log.levels.WARN)
    return
  end
  local branches = {}
  for _, line in ipairs(vim.fn.systemlist({ "git", "worktree", "list", "--porcelain" })) do
    local branch = line:match("^branch refs/heads/(.+)$")
    if branch then
      table.insert(branches, branch)
    end
  end
  vim.ui.select(branches, { prompt = "MR worktree" }, function(choice)
    if choice then
      -- `mr open` reuses the worktree's tmux window (or recreates it) and switches to it.
      vim.fn.jobstart({ mr, "open", choice }, { detach = true })
    end
  end)
end

return {
  { "folke/lazy.nvim", commit = "85c7ff3711b730b4030d03144f6db6375044ae82" }, -- v11.17.5

  { "tpope/vim-surround", commit = "aeb933272e72617f7c4d35e1f003be16836b948d" }, -- v2.2

  -- Claude Code IDE bridge (same WebSocket/MCP protocol as the VS Code extension).
  -- Each nvim writes its own ~/.claude/ide/<port>.lock with its cwd as workspace,
  -- so Claude in the float, or `claude --ide` started in the same worktree, attaches
  -- to *this* nvim. Only in windows opened by `mr` (MR_NAME set): a git commit editor
  -- or nvim in ~ must not advertise a workspace a Claude session could attach to.
  -- Alt+, rather than Ctrl+,: most terminals cannot send Ctrl+, through tmux. Esc is
  -- left to Claude (interrupt), so the float hides with Alt+, only.
  {
    "coder/claudecode.nvim",
    commit = "2390c6e45c4789072c293ac69de051d169668b29",
    dependencies = { "folke/snacks.nvim" },
    cond = function() return vim.env.MR_NAME ~= nil end,
    lazy = false,
    opts = {
      focus_after_send = true,
      terminal = {
        provider = "snacks",
        -- Git root of Neovim's cwd (the worktree `mr` started it in), not of the current
        -- buffer, which may belong to another repo or a sibling worktree.
        cwd_provider = function(ctx) return require("claudecode.cwd").git_root(ctx.cwd) end,
        snacks_win_opts = {
          position = "float",
          width = 0.9,
          height = 0.9,
          border = "rounded",
          keys = {
            claude_hide = { "<M-,>", function(self) self:hide() end, mode = "t", desc = "Claude: hide float" },
            term_normal = false, -- snacks' double-Esc map would take Esc Esc away from Claude
          },
        },
      },
      diff_opts = { open_in_new_tab = true, hide_terminal_in_new_tab = true },
    },
    keys = {
      { "<M-,>", "<cmd>ClaudeCodeFocus<cr>", mode = { "n", "x" }, desc = "Claude: float" },
      { "<leader>aC", "<cmd>ClaudeCode --continue<cr>", desc = "Claude: continue last session" },
      { "<leader>ar", "<cmd>ClaudeCode --resume<cr>", desc = "Claude: pick a session" },
      { "<leader>as", "<cmd>ClaudeCodeSend<cr>", mode = "v", desc = "Claude: send selection" },
      { "<leader>ab", "<cmd>ClaudeCodeAdd %<cr>", desc = "Claude: add buffer" },
      { "<leader>aa", "<cmd>ClaudeCodeDiffAccept<cr>", desc = "Claude: accept diff" },
      { "<leader>ad", "<cmd>ClaudeCodeDiffDeny<cr>", desc = "Claude: deny diff" },
      -- OpenSpec, sent to the float (open it with Alt+, first). Propose waits for the name.
      { "<leader>se", function() claude_send("/opsx:explore", true) end, desc = "OpenSpec: explore" },
      { "<leader>sp", function() claude_send("/opsx:propose ", false) end, desc = "OpenSpec: propose" },
      { "<leader>sa", function() claude_send("/opsx:apply", true) end, desc = "OpenSpec: apply" },
      { "<leader>sA", function() claude_send("/opsx:archive", true) end, desc = "OpenSpec: archive" },
      { "<leader>so", pick_openspec_change, desc = "OpenSpec: change files" },
    },
  },

  -- opencode bridge: targets the opencode session whose directory is nvim's cwd.
  -- Used when the window was opened with MR_AGENT=opencode.
  {
    "nickjvandyke/opencode.nvim",
    commit = "84eabfbe65a44f452ee302fe360cea9fd9939f31", -- v1.0.2
    keys = {
      { "<leader>oa", function() require("opencode").ask("@this: ") end, mode = { "n", "x" }, desc = "opencode: ask" },
      { "<leader>os", function() require("opencode").select() end, mode = { "n", "x" }, desc = "opencode: actions" },
    },
  },

  -- Human review of the MR against its recorded base (stacked MRs included).
  {
    "sindrets/diffview.nvim",
    commit = "4516612fe98ff56ae0415a259ff6361a89419b0a",
    cmd = { "DiffviewOpen", "DiffviewFileHistory", "DiffviewClose" },
    opts = { use_icons = false }, -- no nvim-web-devicons in this setup
    keys = {
      -- One rev: diffview compares it with the working tree, so uncommitted work shows too.
      { "<leader>mr", function() vim.cmd("DiffviewOpen " .. mr_fork_point()) end, desc = "MR: review vs base" },
      { "<leader>mu", "<cmd>DiffviewOpen<cr>", desc = "MR: uncommitted changes" },
      { "<leader>mh", "<cmd>DiffviewFileHistory %<cr>", desc = "MR: file history" },
      { "<leader>mq", "<cmd>DiffviewClose<cr>", desc = "MR: close review" },
    },
  },

  -- Markdown rendered in the buffer with Neovim's bundled markdown parsers; raw text on the
  -- cursor line, never in diff windows. Plain Unicode instead of the default Nerd Font glyphs.
  -- Also carries the OpenSpec review, which needs no Claude session, so it works in any Neovim.
  {
    "MeanderingProgrammer/render-markdown.nvim",
    commit = "640a3ec6d538bad17c328be373c7cad0293d9589", -- v8.14.0
    ft = "markdown",
    cmd = "OpenSpecView",
    opts = {
      heading = { sign = false, icons = { "# ", "## ", "### ", "#### ", "##### ", "###### " } },
      checkbox = {
        unchecked = { icon = "☐ " },
        checked = { icon = "☑ " },
        custom = { todo = { rendered = "◐ " } },
      },
      code = { sign = false, language_icon = false },
      link = { enabled = false },
      latex = { enabled = false }, -- never pipe buffer text to an external LaTeX converter
      callout = plain_callouts(),
    },
    config = function(_, opts)
      require("render-markdown").setup(opts)
      vim.api.nvim_create_user_command("OpenSpecView", openspec_view, {
        nargs = "?",
        complete = function(lead)
          return vim.tbl_filter(function(name) return vim.startswith(name, lead) end, openspec_changes(git_root()))
        end,
        desc = "OpenSpec: review a change in a new tab",
      })
    end,
    keys = {
      { "<leader>sv", "<cmd>OpenSpecView<cr>", desc = "OpenSpec: view a change" },
      { "<leader>sd", openspec_delta_diff, desc = "OpenSpec: delta spec vs main spec" },
    },
  },

  {
    "lewis6991/gitsigns.nvim",
    commit = "a462f416e2ce4744531c6256252dee99a7d34a83", -- v2.1.0
    event = "BufReadPre",
    opts = {},
  },

  { "nvim-lua/plenary.nvim", commit = "74b06c6c75e4eeb3108ec01852001636d85a932b", lazy = true },

  -- Read and answer PR review threads without leaving nvim (needs an authenticated gh).
  {
    "pwntester/octo.nvim",
    commit = "8461d99d13cca243f89848bf4d9fadee096f0a48",
    cmd = "Octo",
    dependencies = { "nvim-lua/plenary.nvim", "folke/snacks.nvim" },
    opts = { picker = "snacks" },
    keys = {
      { "<leader>mp", "<cmd>Octo pr list<cr>", desc = "MR: PR list" },
      { "<leader>mR", "<cmd>Octo review start<cr>", desc = "MR: start PR review" },
    },
  },

  -- Cockpit helpers: jump to another MR window, show the board.
  {
    "folke/snacks.nvim",
    commit = "e6fd58c82f2f3fcddd3fe81703d47d6d48fc7b9f", -- v2.31.0
    keys = {
      { "<leader>mw", pick_worktree, desc = "MR: switch worktree window" },
      {
        "<leader>ml",
        function()
          local mr = mr_tool("mr")
          if not mr then
            vim.notify("mr is not installed (~/.claude/bin/mr)", vim.log.levels.WARN)
            return
          end
          local board = vim.fn.shellescape(mr) .. " ls -p; printf '\\n[any key]'; read -r _"
          Snacks.terminal({ "sh", "-c", board }, { win = { style = "float" } })
        end,
        desc = "MR: board (mr ls -p)",
      },
    },
  },
}
