return {
  name = 'integrate',
  builder = function()
    return {
      cmd = { 'distrobox' },
      args = { 'enter', 'grubhub-dev', '--', 'jenkins', 'integrate' },
      components = {
        { 'on_exit_set_status' },
        { 'custom.on_complete_ntfy' },
      },
    }
  end,
  desc = 'Integrate branch',
}
