return {
  name = 'deploy-branch',
  builder = function()
    return {
      cmd = (function()
        if os.getenv 'CONTAINER_ID' then
          return { 'jenkins', 'deploy-branch' }
        else
          return { 'distrobox', 'enter', 'grubhub-dev', '--', 'jenkins', 'deploy-branch' }
        end
      end)(),
      components = {
        { 'on_exit_set_status' },
        { 'custom.on_complete_ntfy' },
        { 'custom.on_pre_start_deploy_branch' },
      },
    }
  end,
  desc = 'Deploy branch',
}
