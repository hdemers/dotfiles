return {
  name = 'deploy',
  builder = function()
    return {
      cmd = (function()
        if os.getenv 'CONTAINER_ID' then
          return { 'jenkins', 'deploy' }
        else
          local container_name = os.getenv 'DBX_CONTAINER_NAME'
          return { 'distrobox', 'enter', container_name, '--', 'jenkins', 'deploy' }
        end
      end)(),
      components = {
        { 'on_exit_set_status' },
        { 'custom.on_complete_ntfy' },
        { 'custom.on_pre_start_check_pushed' },
      },
    }
  end,
  desc = 'Deploy',
}
