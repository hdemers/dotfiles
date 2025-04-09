return {
  name = 'integrate',
  builder = function()
    return {
      cmd = (function()
        if os.getenv 'CONTAINER_ID' then
          return { 'jenkins', 'integrate' }
        else
          return { 'distrobox', 'enter', 'grubhub-dev', '--', 'jenkins', 'integrate' }
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
