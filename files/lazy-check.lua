-- Managed by ansible-role-vim, which runs it on every run (and after `Lazy! sync`):
-- quits with status 0 only when every plugin is installed on its pinned commit.
local drift = {}
for _, plugin in pairs(require("lazy.core.config").plugins) do
  local head = vim.fn.systemlist({ "git", "-C", plugin.dir, "rev-parse", "HEAD" })[1]
  if not plugin._.installed or (plugin.commit and head ~= plugin.commit) then
    table.insert(drift, plugin.name .. "@" .. tostring(head))
  end
end
if #drift > 0 then
  io.stderr:write("plugins missing or off their pin: " .. table.concat(drift, ", ") .. "\n")
  vim.cmd("cquit 1")
end
vim.cmd("qall")
