-- Managed by ansible-role-vim. Port of the former ~/.vimrc, plus lazy.nvim.

local opt = vim.opt

opt.fileencoding = "utf-8"
opt.termguicolors = false -- wombat256 keeps its 256-colour palette, as in Vim
opt.number = true
opt.cursorline = true
opt.showmatch = true
opt.scrolloff = 5
opt.backup = false
opt.autoread = true
opt.errorbells = false
opt.visualbell = true
opt.history = 500
opt.hlsearch = true
opt.incsearch = true
opt.wildmenu = true
opt.wildmode = "full"

opt.autoindent = true
opt.smartindent = true
opt.tabstop = 2
opt.shiftwidth = 2
opt.expandtab = true
opt.comments = { "sl:/*", "mb: *", "elx: */" }
opt.foldlevelstart = 99
opt.suffixesadd:append(".py")

opt.grepprg = "ack --nogroup $*"
opt.grepformat = "%f:%l:%c:%m"

for _, key in ipairs({ "<Up>", "<Down>", "<Left>", "<Right>" }) do
  vim.keymap.set("", key, "<Nop>")
end

local group = vim.api.nvim_create_augroup("ricofehr", { clear = true })

vim.api.nvim_create_autocmd("BufWritePre", {
  group = group,
  desc = "Strip trailing whitespace",
  callback = function()
    local view = vim.fn.winsaveview()
    vim.cmd([[keeppatterns %s/\s\+$//e]])
    vim.fn.winrestview(view)
  end,
})

local fold_methods = {
  sh = "syntax",
  terraform = "syntax",
  cpp = "syntax",
  go = "syntax",
  yaml = "indent",
  python = "indent",
}

vim.api.nvim_create_autocmd("FileType", {
  group = group,
  pattern = vim.tbl_keys(fold_methods),
  callback = function(args)
    vim.opt_local.foldmethod = fold_methods[args.match]
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  group = group,
  pattern = "python",
  callback = function()
    vim.opt_local.tabstop = 4
    vim.opt_local.shiftwidth = 4
  end,
})

vim.cmd.colorscheme("wombat256")

-- Same commit as the folke/lazy.nvim entry in lua/plugins/agentic-mr.lua (v11.17.5).
local lazy_commit = "85c7ff3711b730b4030d03144f6db6375044ae82"
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({ "git", "clone", "--filter=blob:none", "https://github.com/folke/lazy.nvim.git", lazypath })
  if vim.v.shell_error == 0 then
    vim.fn.system({ "git", "-C", lazypath, "checkout", "--quiet", lazy_commit })
  end
  if vim.v.shell_error ~= 0 then
    vim.fn.delete(lazypath, "rf")
    vim.notify("lazy.nvim bootstrap failed: plugins disabled for this session", vim.log.levels.ERROR)
    return
  end
end
opt.rtp:prepend(lazypath)

require("lazy").setup("plugins", {
  install = { missing = false },
  checker = { enabled = false },
  rocks = { enabled = false },
  change_detection = { notify = false },
})
