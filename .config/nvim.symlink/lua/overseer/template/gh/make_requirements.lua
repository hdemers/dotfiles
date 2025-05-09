return {
  name = 'make-requirements',
  builder = function()
    return {
      cmd = (function()
        if os.getenv 'CONTAINER_ID' then
          return { 'make', 'requirements.txt' }
        else
          local container_name = os.getenv 'DBX_CONTAINER_NAME'
          return { 'distrobox', 'enter', container_name, '--', 'make', 'requirements.txt' }
        end
      end)(),
      components = {
        { 'on_exit_set_status' },
        { 'custom.on_complete_ntfy' },
      },
    }
  end,
  desc = 'Run make requirements.txt',
}
