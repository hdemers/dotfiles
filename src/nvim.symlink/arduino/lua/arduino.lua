-- vim: ts=2 sts=2 sw=2 et
local M = {}

M.setup = function()
  print 'Arduino setup'

  local overseer = require 'overseer'
  overseer.load_template 'misc.compile_sketch'
  overseer.load_template 'misc.upload_sketch'
  overseer.load_template 'misc.monitor_sketch'

  vim.api.nvim_create_user_command('ArduinoRun', function()
    -- local task = overseer.new_task {
    --   name = 'Compile, upload and monitor',
    --   strategy = {
    --     'orchestrator',
    --     tasks = {
    --       'compile-sketch',
    --       -- 'misc.upload_sketch',
    --       -- 'misc.monitor_sketch',
    --     },
    --   },
    -- }
    -- task:start()
    --
    -- task:subscribe('on_start', function(t, _)
    --   local main_win = vim.api.nvim_get_current_win()
    --   overseer.run_action(t, 'open vsplit')
    --   vim.api.nvim_set_current_win(main_win)
    -- end)

    overseer.run_template({ name = 'monitor-sketch', autostart = false }, function(task)
      if task then
        task:add_component {
          'dependencies',
          task_names = {
            'compile-sketch',
            'upload-sketch',
          },
          sequential = true,
        }
        task:start()

        task:subscribe('on_start', function(t, _)
          local main_win = vim.api.nvim_get_current_win()
          overseer.run_action(t, 'open vsplit')
          vim.api.nvim_set_current_win(main_win)
        end)
      else
        vim.notify(
          'ArduinoRun not supported for filetype ' .. vim.bo.filetype,
          vim.log.levels.ERROR
        )
      end
    end)
  end, {})
end

return M
