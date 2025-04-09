return {
  name = 'deploy',
  builder = function()
    return {
      cmd = (function()
        if os.getenv 'CONTAINER_ID' then
          return { 'jenkins', 'deploy' }
        else
          return { 'distrobox', 'enter', 'grubhub-dev', '--', 'jenkins', 'deploy' }
        end
      end)(),
      components = {
        { 'on_exit_set_status' },
        { 'custom.on_complete_ntfy' },
        { 'custom.on_pre_start_deploy_branch' },
      },
    }
  end,
  desc = 'Deploy',
}
