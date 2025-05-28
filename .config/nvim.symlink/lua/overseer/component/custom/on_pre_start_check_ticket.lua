return {
  desc = 'Check that all commits to be integrated have a ticket.',
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
        local branch = vim.fn.system('git rev-parse --abbrev-ref HEAD'):gsub('\n', '')

        -- Detect the default/base branch name
        local base_branch = vim.fn
          .system('git symbolic-ref refs/remotes/origin/HEAD')
          :gsub('\n', '')
          :gsub('refs/remotes/origin/', '')
        if vim.v.shell_error ~= 0 or base_branch == '' then
          -- Fallback: try common base branch names
          local common_bases = { 'main', 'master', 'develop' }
          for _, base in ipairs(common_bases) do
            local check_cmd =
              string.format('git show-ref --verify --quiet refs/heads/%s', base)
            if vim.fn.system(check_cmd) and vim.v.shell_error == 0 then
              base_branch = base
              break
            end
          end
          if base_branch == '' then
            base_branch = 'main' -- Final fallback
          end
        end

        -- Get commit hashes that will be integrated/merged
        local git_cmd = string.format('git log %s..%s --format=%%H', base_branch, branch)
        local commit_hashes = vim.fn.system(git_cmd)

        if vim.v.shell_error ~= 0 then
          vim.notify(
            'Failed to get commit list. Make sure you are in a git repository and base branch exists.',
            vim.log.levels.ERROR
          )
          return false
        end

        if commit_hashes == '' then
          vim.notify('No commits to integrate.', vim.log.levels.ERROR)
          return false
        end

        -- Generic Jira ticket pattern: PROJECT-NUMBER
        local jira_pattern = '[A-Z][A-Z0-9]*%-[0-9]+'

        local commits_without_tickets = {}
        local hash_lines = vim.split(commit_hashes, '\n')

        for _, commit_hash in ipairs(hash_lines) do
          if commit_hash ~= '' then
            -- Get the full commit message (title + body)
            local full_message_cmd =
              string.format('git log -1 --format=%%B %s', commit_hash)
            local full_message = vim.fn.system(full_message_cmd)

            -- Get just the oneline for display purposes
            local oneline_cmd = string.format('git log -1 --oneline %s', commit_hash)
            local oneline = vim.fn.system(oneline_cmd):gsub('\n', '')

            local has_ticket = full_message:match(jira_pattern) ~= nil

            if not has_ticket then
              table.insert(commits_without_tickets, oneline)
            end
          end
        end

        if #commits_without_tickets > 0 then
          local error_msg =
            'The following commits do not have Jira ticket numbers in title or body:\n\n'
          for _, commit in ipairs(commits_without_tickets) do
            error_msg = error_msg .. '  • ' .. commit .. '\n'
          end
          vim.notify(error_msg, vim.log.levels.ERROR)
          return false
        end
        return true
      end,
    }
  end,
}
