-- vim: ts=2 sts=2 sw=2 et
local M = {}

M.setup = function() end

M.ntfy = function(title, message, tags, priority)
  local on_exit = vim.schedule_wrap(function(obj)
    if obj.code ~= 0 then
      vim.notify('ntfy failed', vim.log.levels.ERROR)
    end
  end)

  local channel = os.getenv 'NTFY_NEPTUNE_CHANNEL'

  if channel == nil then
    vim.notify('NTFY_NEPTUNE_CHANNEL is not set', vim.log.levels.ERROR)
    return
  end

  if priority == nil then
    priority = 3
  end

  local cmd = {
    'curl',
    '-d',
    message,
    'ntfy.sh/' .. channel,
    '-H',
    'x-title:' .. title,
    '-H',
    'x-priority:' .. priority,
  }

  if tags then
    table.insert(cmd, '-H')
    table.insert(cmd, 'tags:' .. tags)
  end

  vim.system(cmd, { text = true }, on_exit)
end

return M
