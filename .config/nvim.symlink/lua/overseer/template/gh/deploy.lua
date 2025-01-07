return {
  name = 'deploy',
  builder = function()
    return {
      cmd = { 'distrobox' },
      args = { 'enter', 'grubhub-dev', '--', 'jenkins', 'deploy' },
      components = {
        { 'on_exit_set_status' },
        { 'custom.on_complete_ntfy' },
        { 'custom.on_pre_start_deploy_branch' },
      },
    }
  end,
  desc = 'Deploy',
}
