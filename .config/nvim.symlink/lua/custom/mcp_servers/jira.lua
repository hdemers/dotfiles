local M = {}

-- Add the Jira describe tool
local function setup_jira_server()
  local mcphub = require 'mcphub'

  mcphub.add_tool('jira', {
    name = 'transition_ticket',
    description = 'Transition a Jira ticket. Transition chain is: New -> Refined -> In Dev -> In Review -> Merged -> Closed',
    inputSchema = {
      type = 'object',
      properties = {
        transition = {
          type = 'string',
          description = 'The transition to apply to the Jira ticket',
        },
        ticket = {
          type = 'string',
          description = 'The Jira ticket to transition',
        },
      },
      required = { 'ticket', 'transition' },
    },
    handler = function(req, res)
      local ticket = req.params.ticket
      local transition = req.params.transition

      local cmd = 'jira transition-to ' .. ticket .. ' ' .. transition
      local output = vim.fn.system(cmd)

      -- Check if command was successful
      if vim.v.shell_error ~= 0 then
        return res:error(
          'Failed to transition ' .. ticket .. ' to  ' .. transition .. ': ' .. output
        )
      end

      return res:text(output):send()
    end,
  })

  mcphub.add_tool('jira', {
    name = 'create_ticket',
    description = 'Create a new Jira ticket',
    inputSchema = {
      type = 'object',
      properties = {
        summary = {
          type = 'string',
          description = 'The summary of the Jira ticket',
        },
        points = {
          type = 'string',
          description = 'The story points, can be None, 0, 0.5, 1, 2, 3, 5, 8',
        },
        sprint = {
          type = 'string',
          description = 'The sprint to assign the Jira ticket to, can be empty',
        },
        epic = {
          type = 'string',
          description = 'The epic to assign the Jira ticket to, can be empty',
        },
        assignee = {
          type = 'string',
          description = 'The assignee of the Jira ticket, either "me" or empty',
        },
        description = {
          type = 'string',
          description = 'The description of the Jira ticket',
        },
      },
      required = { 'summary', 'description', 'epic' },
    },
    handler = function(req, res)
      local cmd = 'jira create '
        .. '--summary "'
        .. req.params.summary
        .. '" '
        .. '--points '
        .. req.params.points
        .. ' '
        .. '--sprint '
        .. (req.params.sprint or '')
        .. ' '
        .. '--epic '
        .. (req.params.epic or '')
        .. ' '
        .. '--assignee '
        .. (req.params.assignee or '')
        .. ' '
        .. '--description "'
        .. req.params.description
        .. '"'

      local output = vim.fn.system(cmd)

      -- Check if command was successful
      if vim.v.shell_error ~= 0 then
        return res:error('Failed to create ticket : ' .. output)
      end

      return res:text(output):send()
    end,
  })

  mcphub.add_tool('jira', {
    name = 'close_ticket',
    description = 'Close a Jira ticket',
    inputSchema = {
      type = 'object',
      properties = {
        ticket = {
          type = 'string',
          description = 'The Jira ticket to close',
        },
      },
      required = { 'ticket' },
    },
    handler = function(req, res)
      local ticket = req.params.ticket

      local cmd = 'jira close ' .. ticket
      local output = vim.fn.system(cmd)

      -- Check if command was successful
      if vim.v.shell_error ~= 0 then
        return res:error('Failed to close ticket ' .. ticket .. ': ' .. output)
      end

      return res:text(output):send()
    end,
  })

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
    name = 'tickets',
    uri = 'jira://tickets',
    description = 'List of Jira tickets',
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

  mcphub.add_resource('jira', {
    name = 'epics',
    uri = 'jira://epics',
    description = 'List of Jira epics.',
    handler = function(req, res)
      -- Execute jira issue list command (adjust the query as needed)
      local cmd = 'jira issues --epics-only --llm'
      local output = vim.fn.system(cmd)

      -- Check if command was successful
      if vim.v.shell_error ~= 0 then
        return res:error('Failed to get recent tickets: ' .. output)
      end

      return res:text(output):send()
    end,
  })

  mcphub.add_resource('jira', {
    name = 'sprints',
    uri = 'jira://sprints',
    description = 'List of Jira sprints.',
    handler = function(req, res)
      -- Execute jira issue list command (adjust the query as needed)
      local cmd = 'jira sprints --llm'
      local output = vim.fn.system(cmd)

      -- Check if command was successful
      if vim.v.shell_error ~= 0 then
        return res:error('Failed to list sprints: ' .. output)
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
