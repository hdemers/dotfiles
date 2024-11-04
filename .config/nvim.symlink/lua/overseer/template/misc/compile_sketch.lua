return {
  name = 'compile-sketch',
  builder = function()
    local file = vim.fn.expand '%:p'

    return {
      cmd = { 'arduino-cli' },
      args = { 'compile', '--quiet', file },
      components = {
        -- { 'open_output', on_complete = 'failure' },
        { 'on_result_diagnostics_quickfix', open = true },
        { 'on_exit_set_status' },
      },
    }
  end,
  condition = {
    filetype = { 'arduino' },
  },
  desc = 'Compile arduino sketch',
}
