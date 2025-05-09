return {
  name = 'make-test',
  builder = function()
    local container_name = os.getenv 'DBX_CONTAINER_NAME'
    return {
      cmd = { 'distrobox' },
      args = { 'enter', container_name, '--', 'make', 'test' },
      components = {
        { 'on_exit_set_status' },
        { 'custom.on_complete_ntfy' },
      },
    }
  end,
  desc = 'Run make test',
}
