local M = {}

function M.setup()
  -- Add the Jira describe tool
  local mcphub = require 'mcphub'

  -- Add a prompt to generate a commit message with Jira ticket
  mcphub.add_prompt('prompts', {
    name = 'commit_with_ticket',
    description = 'Generate a commit message with Jira ticket',
    arguments = {
      {
        name = 'ticket',
        description = 'Jira ticket',
        required = true,
      },
    },
    handler = function(req, res)
      local ticket = req.params.ticket
      local changes = req.params.changes or 'the changes'
      local repo = vim.fn.system 'git rev-parse --show-toplevel'
      local branch = vim.fn.system 'git rev-parse --abbrev-ref HEAD'

      return res
        :user()
        :text(
          string.format(
            [[Help me write a commit message for ticket %s explaining the changes in 
            the staged files, on branch %s, repository %s. Use the `git_diff_staged` 
            tool from @mcp.
            ]],
            ticket,
            branch,
            repo
          )
        )
        :send()
    end,
  })
  mcphub.add_prompt('prompts', {
    name = 'open_pr',
    description = 'Open a pull request',
    handler = function(req, res)
      local repo = vim.fn.system 'git rev-parse --show-toplevel'
      local branch = vim.fn.system 'git rev-parse --abbrev-ref HEAD'

      return res
        :user()
        :text(string.format(
          [[Open a PR for branch %s in repository %s. 
            Ask the user for approval before opening the PR. @mcp
            ]],
          branch,
          repo
        ))
        :send()
    end,
  })

  -- Initialize the server when this module is loaded
end

return M
