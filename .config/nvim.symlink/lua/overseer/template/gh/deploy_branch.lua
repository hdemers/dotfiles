return {
  name = 'deploy-branch',
  builder = function()
    return {
      cmd = { 'jenkins' },
      args = { 'deploy-branch' },
      components = {
        { 'on_exit_set_status' },
        { 'custom.on_complete_ntfy' },
      },
    }
  end,
  desc = 'Deploy branch',
}
