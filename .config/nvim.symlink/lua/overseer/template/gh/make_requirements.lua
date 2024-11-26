return {
  name = 'make-requirements',
  builder = function()
    return {
      cmd = { 'make' },
      args = { 'requirements.txt' },
      components = {
        { 'on_exit_set_status' },
        { 'custom.on_complete_ntfy' },
      },
    }
  end,
  desc = 'Run make requirements.txt',
}
