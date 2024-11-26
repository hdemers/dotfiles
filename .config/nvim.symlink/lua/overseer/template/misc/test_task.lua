return {
  name = 'test-task',
  builder = function()
    return {
      cmd = { 'ls' },
      components = {
        { 'on_exit_set_status' },
        { 'custom.on_complete_ntfy' },
      },
    }
  end,
  desc = 'A test task',
}
