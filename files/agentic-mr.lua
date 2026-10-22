-- Managed by ansible-role-vim. Agentic multi-MR workflow (lazy.nvim spec).
-- One Neovim per git worktree, started by `mr` in the left tmux pane; the
-- agent (claude / opencode) runs in the right pane of the same window.
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
  -- so `claude --ide` started in the same worktree attaches to *this* nvim. Only in
  -- windows opened by `mr` (MR_NAME set): a git commit editor or nvim in ~ must not
  -- advertise a workspace a Claude session could attach to.
  {
    "coder/claudecode.nvim",
    commit = "2390c6e45c4789072c293ac69de051d169668b29",
    dependencies = { "folke/snacks.nvim" },
    cond = function() return vim.env.MR_NAME ~= nil end,
    lazy = false,
    opts = {
      terminal = { provider = "none" }, -- claude lives in the tmux pane, not in nvim
    },
    keys = {
      { "<leader>as", "<cmd>ClaudeCodeSend<cr>", mode = "v", desc = "Claude: send selection" },
      { "<leader>ab", "<cmd>ClaudeCodeAdd %<cr>", desc = "Claude: add buffer" },
      { "<leader>aa", "<cmd>ClaudeCodeDiffAccept<cr>", desc = "Claude: accept diff" },
      { "<leader>ad", "<cmd>ClaudeCodeDiffDeny<cr>", desc = "Claude: deny diff" },
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
      { "<leader>mr", function() vim.cmd("DiffviewOpen " .. mr_base() .. "...HEAD") end, desc = "MR: review vs base" },
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
