return {
  name = 'compile-sketch',
  builder = function()
    local file = vim.fn.expand '%:p'

    return {
      cmd = { 'arduino-cli' },
      args = { 'compile', file },
    }
  end,
  condition = {
    filetype = { 'arduino' },
  },
  desc = 'Compile arduino sketch',
}
