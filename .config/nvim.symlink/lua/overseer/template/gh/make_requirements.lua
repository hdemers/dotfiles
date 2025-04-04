return {
  name = 'make-requirements',
  builder = function()
    return {
      cmd = { 'distrobox' },
      args = { 'enter', 'grubhub-dev', '--', 'make', 'requirements.txt' },
      components = {
        { 'on_exit_set_status' },
        { 'custom.on_complete_ntfy' },
      },
    }
  end,
  desc = 'Run make requirements.txt',
}
