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

-- Picker on the worktree's openspec/changes/, from the same root Claude starts in.
local function pick_openspec_change()
  local root = require("claudecode.cwd").git_root(vim.fn.getcwd()) or vim.fn.getcwd()
  local changes = root .. "/openspec/changes"
  if vim.fn.isdirectory(changes) == 0 then
    vim.notify("no openspec/changes in " .. root, vim.log.levels.WARN)
    return
  end
  Snacks.picker.files({ cwd = changes })
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
