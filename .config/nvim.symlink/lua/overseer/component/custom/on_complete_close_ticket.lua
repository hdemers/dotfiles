return {
  desc = 'Close ticket on integrate',
  -- Define parameters that can be passed in to the component
  params = {
    -- See :help overseer-params
  },
  -- Optional, default true. Set to false to disallow editing this component in the task editor
  editable = true,
  -- Optional, default true. When false, don't serialize this component when saving a task to disk
  serializable = true,
  -- The params passed in will match the params defined above
  constructor = function(params)
    -- You may optionally define any of the methods below
    return {
      ---@param status overseer.constants.STATUS Can be CANCELED, FAILURE, or SUCCESS
      ---@param result table A result table.
      on_complete = function(self, task, status, result)
        -- Called when the task has reached a completed state.
        local constants = require 'overseer.constants'
        local STATUS = constants.STATUS

        vim.notify(
          'Task ' .. task.name .. ' completed with status: ' .. status,
          vim.log.levels.INFO
        )

        vim.notify('Task metadata: ' .. vim.inspect(task.metadata), vim.log.levels.DEBUG)
        vim.notify(
          'Ticket is: ' .. (task.metadata.ticket or 'None'),
          vim.log.levels.DEBUG
        )

        if status == STATUS.SUCCESS and task.metadata.ticket then
          local output = vim.fn.system 'jira close ' .. task.metadata.ticket

          if vim.v.shell_error ~= 0 then
            vim.notify('Failed to close ticket: ' .. output, vim.log.levels.ERROR)
          else
            vim.notify(
              'Ticket ' .. task.metadata.ticket .. ' closed successfully.',
              vim.log.levels.INFO
            )
          end
        elseif status == STATUS.SUCCESS then
          vim.notify('No ticket to close.', vim.log.levels.WARN)
        end
      end,
    }
  end,
}
