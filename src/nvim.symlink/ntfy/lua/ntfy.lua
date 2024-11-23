-- vim: ts=2 sts=2 sw=2 et
local M = {}

M.setup = function() end

M.ntfy = function(title, message, tags)
  local on_exit = vim.schedule_wrap(function(obj)
    if obj.code ~= 0 then
      vim.notify('ntfy failed', vim.log.levels.ERROR)
    end
  end)

  local cmd = {
    'curl',
    '-d',
    message,
    'ntfy.sh/hdemers',
    '-H',
    'x-title:' .. title,
    '-H',
    'tags:' .. tags,
  }
  vim.system(cmd, { text = true }, on_exit)
end

return M
