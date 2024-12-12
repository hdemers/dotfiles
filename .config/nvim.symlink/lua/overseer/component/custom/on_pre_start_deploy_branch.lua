return {
  desc = 'Check the branch has been pushed to Github',
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
      on_pre_start = function(self, task)
        -- Get current branch name
        local branch = vim.fn.system('git rev-parse --abbrev-ref HEAD'):gsub('\n', '')

        -- Fetch latest from remote
        vim.fn.system 'git fetch'

        -- Get local and remote HEADs
        local local_head = vim.fn.system('git rev-parse HEAD'):gsub('\n', '')
        local remote_head =
          vim.fn.system('git rev-parse origin/' .. branch):gsub('\n', '')

        if local_head ~= remote_head then
          vim.notify(
            'Local branch is not in sync with remote.\n'
              .. 'Please push your changes before deploying.',
            vim.log.levels.ERROR
          )
          return false
        end

        return true
      end,
    }
  end,
}
