return {
  name = 'monitor-sketch',
  builder = function()
    local file = vim.fn.expand '%:p'

    return {
      cmd = { 'arduino-cli' },
      args = { 'monitor', file },
      -- strategy = {
      --   'toggleterm',
      -- },
    }
  end,
  condition = {
    filetype = { 'arduino' },
  },
  desc = 'Monitor arduino sketch',
}
