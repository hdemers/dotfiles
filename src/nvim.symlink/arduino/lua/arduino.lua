-- vim: ts=2 sts=2 sw=2 et
local M = {}

M.setup = function()
  local overseer = require 'overseer'
  local running_task

  overseer.load_template 'misc.compile_sketch'
  overseer.load_template 'misc.upload_sketch'
  overseer.load_template 'misc.monitor_sketch'

  vim.api.nvim_create_user_command('ArduinoRun', function()
    overseer.run_template({ name = 'monitor-sketch', autostart = false }, function(task)
      if task then
        running_task = task
        task:start()

        task:subscribe('on_start', function(t, _)
          local main_win = vim.api.nvim_get_current_win()
          overseer.run_action(t, 'open vsplit')
          vim.api.nvim_set_current_win(main_win)
        end)

        task:subscribe('on_complete', function(t, _)
          vim.api.nvim_buf_delete(t.prev_bufnr, { force = true })
        end)
      end
    end)
  end, {})

  vim.api.nvim_create_user_command('ArduinoStop', function()
    if running_task then
      running_task:stop()
    end
  end, {})
end

return M
