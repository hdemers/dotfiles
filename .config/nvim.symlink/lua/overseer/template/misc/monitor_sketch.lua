return {
  name = 'monitor-sketch',
  builder = function()
    local file = vim.fn.expand '%:p'

    return {
      cmd = { 'arduino-cli' },
      args = { 'monitor', file },
      components = {
        { 'dependencies', task_names = { 'upload-sketch' } },
        { 'on_exit_set_status' },
      },
    }
  end,
  condition = {
    filetype = { 'arduino' },
  },
  desc = 'Monitor arduino sketch',
}
