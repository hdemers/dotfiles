return {
  name = 'test-task',
  builder = function()
    local on_complete = function()
      vim.notify 'on_complete'
    end

    return {
      cmd = { 'ls' },
      components = {
        { 'on_complete', on_complete },
        { 'on_exit_set_status' },
      },
    }
  end,
  desc = 'A test task',
}
