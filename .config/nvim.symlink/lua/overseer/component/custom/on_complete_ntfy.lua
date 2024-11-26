return {
  desc = 'Call ntfy on complete',
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
        local ntfy = require 'ntfy'
        local tags
        local priority = 4

        if status == STATUS.CANCELED then
          tags = 'no_entry_sign'
        elseif status == STATUS.FAILURE then
          tags = 'rotating_light'
        elseif status == STATUS.SUCCESS then
          tags = 'rocket'
        end
        ntfy.ntfy(task.name, 'Completed with status ' .. status, tags, priority)
      end,
    }
  end,
}
