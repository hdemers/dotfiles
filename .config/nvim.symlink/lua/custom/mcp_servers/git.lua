local M = {}

-- Add the Makefile describe tool
local function setup_git_server()
  local mcphub = require 'mcphub'

  -- Create a tool to execute Makefile targets
  mcphub.add_tool('custom_git', {
    name = 'git_log_from_to',
    description = 'Git log from one commit/branch to another',
    inputSchema = {
      type = 'object',
      properties = {
        from = {
          type = 'string',
          description = 'The commit hash or branch to start from',
        },
        to = {
          type = 'string',
          description = 'The commit hash or branch to end at',
        },
      },
      required = { 'to' },
    },
    handler = function(req, res)
      local from = req.params.from
      local to = req.params.to

      if not from then
        from = 'HEAD'
      end

      local cmd = 'git log ' .. from .. '..' .. to
      local output = vim.fn.system(cmd)

      -- Check if command was successful
      if vim.v.shell_error ~= 0 then
        return res:error('Failed to run ' .. cmd .. ': ' .. output)
      end

      return res:text(output):send()
    end,
  })

  -- Add a prompt to generate a commit message with Jira ticket
  mcphub.add_prompt('custom_git', {
    name = 'commit_with_ticket',
    description = 'Generate a commit message with Jira ticket',
    arguments = {
      {
        name = 'ticket',
        description = 'Jira ticket',
        required = false,
      },
    },
    handler = function(req, res)
      local repo = vim.fn.system 'git rev-parse --show-toplevel'
      local ticket = req.params.ticket or ''
      local branch = vim.fn.system 'git rev-parse --abbrev-ref HEAD'
      local prompt = string.format(
        [[
          1. Write a commit message (DO NOT COMMIT) for the files staged in repository %s on branch %s
          2. Ask the user for the Jira commit ticket number. (DO NOT COMMIT)
          3. Add the ticket number on a line of its own at the end of the commit message.
          4. Ask the user to review the commit message. @mcp]],
        repo,
        branch
      )
      return res:user():text(prompt):send()
    end,
  })
  mcphub.add_prompt('custom_git', {
    name = 'open_pr',
    description = 'Open a pull request',
    handler = function(req, res)
      local repo = vim.fn.system 'git rev-parse --show-toplevel'
      local remote_url = vim.fn.system 'git config --get remote.origin.url'
      local main_branch_name =
        vim.fn.system 'git symbolic-ref refs/remotes/origin/HEAD | sed "s@^refs/remotes/origin/@@"'
      local branch = vim.fn.system 'git rev-parse --abbrev-ref HEAD'

      return res
        :user()
        :text(string.format(
          [[
Open a PR for branch '%s' in repository _%s_ (remote URL: %s). 

Follow these instructions closely:

1. If there's a template file in .github/PULL_REQUEST_TEMPLATE.md use it.
2. The commits part of this PR are those between HEAD and %s, use the `git_log_from_to` tool.
3. Use the commit's messages part of this PR as the basis for the PR description.
4. Ask the user for approval before opening the PR.

@mcp
]],
          branch,
          repo,
          remote_url,
          main_branch_name
        ))
        :send()
    end,
  })
end

-- Initialize the server when this module is loaded
function M.setup()
  setup_git_server()

  -- Setup key mappings for the prompts
  -- vim.keymap.set('n', '<leader>aox', function()
  --   require('mcphub')
  --     .get_hub_instance()
  --     .get_prompt('git', 'commit_with_ticket', { ticket = '' })
  -- end, { desc = 'Generate commit message with Jira ticket' })
end

return M
