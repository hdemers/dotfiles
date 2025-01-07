return {
  name = 'make-test',
  builder = function()
    return {
      cmd = { 'distrobox' },
      args = { 'enter', 'grubhub-dev', '--', 'make', 'test' },
      components = {
        { 'on_exit_set_status' },
        { 'custom.on_complete_ntfy' },
      },
    }
  end,
  desc = 'Run make test',
}
