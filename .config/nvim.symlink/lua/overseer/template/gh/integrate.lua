return {
  name = 'integrate',
  builder = function()
    return {
      cmd = (function()
        if os.getenv 'CONTAINER_ID' then
          return { 'jenkins', 'integrate' }
        else
          local container_name = os.getenv 'DBX_CONTAINER_NAME'
          return { 'distrobox', 'enter', container_name, '--', 'jenkins', 'integrate' }
        end
      end)(),
      components = {
        { 'on_exit_set_status' },
        { 'custom.on_complete_ntfy' },
      },
    }
  end,
  desc = 'Integrate branch',
}
