-- vim: ts=2 sts=2 sw=2 et
local M = {}

M.setup = function()
  -- Create keymap for jujutsy_new
  vim.keymap.set('n', '<localleader>jn', function()
    M.jujutsu_new()
  end, { desc = 'Create new Jujutsu commit', silent = true })
end

M.jujutsu_new = function()
  local cmd = 'jj new'
  local output = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 then
    vim.notify('Error creating new Jujutsu commit: ' .. output, vim.log.levels.ERROR)
    return
  end
  vim.notify('New Jujutsu commit created:\n' .. output, vim.log.levels.INFO)
end

return M
