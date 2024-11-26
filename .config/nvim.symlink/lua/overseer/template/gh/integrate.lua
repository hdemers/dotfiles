return {
  name = 'integrate',
  builder = function()
    return {
      cmd = { 'jenkins' },
      args = { 'integrate' },
      components = {
        { 'on_exit_set_status' },
        { 'custom.on_complete_ntfy' },
      },
    }
  end,
  desc = 'Integrate branch',
}
