return {
  name = 'make-test',
  builder = function()
    return {
      cmd = { 'make' },
      args = { 'test' },
      components = {
        { 'on_exit_set_status' },
        { 'custom.on_complete_ntfy' },
      },
    }
  end,
  desc = 'Run make test',
}
