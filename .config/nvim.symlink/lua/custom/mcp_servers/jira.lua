local M = {}

-- Add the Jira describe tool
local function setup_jira_server()
  local mcphub = require 'mcphub'

  -- Create a tool to describe Jira tickets
  mcphub.add_resource_template('jira', {
    name = 'describe_ticket',
    uriTemplate = 'jira://tickets/{ticket}',
    description = 'Jira ticket description',
    handler = function(req, res)
      local ticket = req.params.ticket

      -- Validate the ticket format (basic validation)
      if not string.match(ticket, '%a+%-%d+') then
        return res:error 'Invalid ticket format. Should be like PROJECT-123'
      end

      -- Execute the jira describe command
      local cmd = 'jira describe --llm ' .. ticket
      local output = vim.fn.system(cmd)

      -- Check if command was successful
      if vim.v.shell_error ~= 0 then
        return res:error('Failed to get ticket details: ' .. output)
      end

      return res:text(output):send()
    end,
  })

  mcphub.add_resource('jira', {
    name = 'recent_tickets',
    uri = 'jira://tickets',
    description = 'List of recent Jira tickets',
    handler = function(req, res)
      -- Execute jira issue list command (adjust the query as needed)
      local cmd = 'jira issues --llm'
      local output = vim.fn.system(cmd)

      -- Check if command was successful
      if vim.v.shell_error ~= 0 then
        return res:error('Failed to get recent tickets: ' .. output)
      end

      return res:text(output):send()
    end,
  })

  mcphub.add_resource('jira', {
    name = 'tickets_assigned_to_me',
    uri = 'jira://tickets/mine',
    description = 'List of Jira tickets assigned to me.',
    handler = function(req, res)
      -- Execute jira issue list command (adjust the query as needed)
      local cmd = 'jira issues --mine --llm'
      local output = vim.fn.system(cmd)

      -- Check if command was successful
      if vim.v.shell_error ~= 0 then
        return res:error('Failed to get recent tickets: ' .. output)
      end

      return res:text(output):send()
    end,
  })

  mcphub.add_resource('jira', {
    name = 'tickets_assigned_to_me_current_sprint',
    uri = 'jira://tickets/mine/current',
    description = 'List of Jira tickets assigned to me in the current sprint.',
    handler = function(req, res)
      -- Execute jira issue list command (adjust the query as needed)
      local cmd = 'jira issues --mine --current-sprint --llm'
      local output = vim.fn.system(cmd)

      -- Check if command was successful
      if vim.v.shell_error ~= 0 then
        return res:error('Failed to get recent tickets: ' .. output)
      end

      return res:text(output):send()
    end,
  })
end

-- Initialize the server when this module is loaded
function M.setup()
  setup_jira_server()
end

return M
