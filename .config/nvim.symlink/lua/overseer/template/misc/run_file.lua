return {
  name = 'run-file',
  builder = function()
    local file = vim.fn.expand '%:p'
    local cmd = { file }
    if vim.bo.filetype == 'python' then
      cmd = { 'python', file }
    end

    return {
      cmd = cmd,
      components = {
        { 'on_output_quickfix', set_diagnostics = true },
        'on_result_diagnostics',
        'default',
      },
    }
  end,
  condition = {
    filetype = { 'sh', 'python' },
  },
}
