local M = {}

local function setup_pytest_server()
  local mcphub = require 'mcphub'

  -- Create a tool to execute Makefile targets
  mcphub.add_tool('pytest', {
    name = 'pytest_run',
    description = 'Run pytest tests',
    inputSchema = {
      type = 'object',
      properties = {
        path = {
          type = 'string',
          description = 'Path to the test file or directory to run.',
        },
        expression_filter = {
          type = 'string',
          description = 'Only run tests which match the given expression filter',
        },
      },
    },
    handler = function(req, res)
      local path = req.params.package or ''
      local expression_filter = req.params.expression_filter or ''

      local args = path
      if expression_filter ~= '' then
        args = ' -k ' .. expression_filter .. ' ' .. path
      end

      local cmd = 'pytest ' .. args
      local output = vim.fn.system(cmd)

      return res:text(output):send()
    end,
  })
end

-- Initialize the server when this module is loaded
function M.setup()
  setup_pytest_server()
end

return M
