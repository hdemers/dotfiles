-- vim: ts=2 sts=2 sw=2 et
local M = {}

M.terminal_instance = nil

local function close_on_keypress(win, buf)
  local close = function()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  for _, key in ipairs { '<Esc>', 'q', '<CR>', '<Space>', 'i', 'a', 'o' } do
    vim.keymap.set('n', key, close, { buffer = buf, nowait = true })
  end
end

M.setup = function()
  vim.keymap.set('n', '<leader>jn', M.jujutsu_new, { desc = 'Create new Jujutsu commit' })
  vim.keymap.set(
    'n',
    '<leader>jj',
    M.jujutsu_quick_view,
    { desc = 'Quick view jj status' }
  )
end

M.jujutsu_new = function()
  local output = vim.fn.system 'jj new'
  local is_success = vim.v.shell_error == 0
  local level = is_success and vim.log.levels.INFO or vim.log.levels.ERROR
  local prefix = is_success and 'New Jujutsu commit created:\n'
    or 'Error creating commit: '
  vim.notify(prefix .. output, level)
end

M.jujutsu_quick_view = function()
  local output = vim.fn.system('cd ' .. vim.fn.getcwd() .. ' && jj --color=always')

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(output, '\n'))
  vim.bo[buf].filetype = 'jujutsu'

  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    anchor = 'NW',
    row = 0,
    col = 0,
    width = 100,
    height = vim.o.lines - 3,
    border = 'rounded',
    style = 'minimal',
  })

  vim.bo[buf].modifiable = true
  Snacks.terminal.colorize()
  vim.bo[buf].modifiable = false

  close_on_keypress(win, buf)
end

return M
