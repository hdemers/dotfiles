local M = {}

local function setup_notify_server()
  local mcphub = require 'mcphub'

  mcphub.add_tool('notify', {
    name = 'notify_user',
    description = 'Send a notification to the user',
    inputSchema = {
      type = 'object',
      properties = {
        message = {
          type = 'string',
          description = 'Your message to the user',
        },
      },
      required = { 'message' },
    },
    handler = function(req, res)
      local message = req.params.message
      local ntfy = require 'ntfy'
      local tags = 'loudspeaker'
      local priority = 4

      ntfy.ntfy('AI Agent', message, tags, priority)

      return res:text('User has been notified'):send()
    end,
  })
end

-- Initialize the server when this module is loaded
function M.setup()
  setup_notify_server()
end

return M
