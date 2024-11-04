return {
  name = 'upload-sketch',
  builder = function()
    local file = vim.fn.expand '%:p'

    return {
      cmd = { 'arduino-cli' },
      args = { 'upload', file },
      components = {
        { 'dependencies', task_names = { 'compile-sketch' } },
        { 'on_exit_set_status' },
      },
    }
  end,
  condition = {
    filetype = { 'arduino' },
  },
  desc = 'Upload arduino sketch',
}
