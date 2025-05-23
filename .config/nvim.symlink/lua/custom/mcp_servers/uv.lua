local M = {}

-- Add the Jira describe tool
local function setup_jira_server()
  local mcphub = require 'mcphub'

  -- Create a tool to describe Jira tickets
  mcphub.add_tool('uv', {
    name = 'uv_pip_install_package',
    description = 'Install package with uv pip',
    inputSchema = {
      type = 'object',
      properties = {
        package = {
          type = 'string',
          description = 'Package name to install',
        },
      },
      required = { 'package' },
    },
    handler = function(req, res)
      local package = req.params.package

      -- Execute the jira describe command
      local cmd = 'uv pip install ' .. package
      local output = vim.fn.system(cmd)

      -- Check if command was successful
      if vim.v.shell_error ~= 0 then
        return res:error('Failed to install package: ' .. output)
      end

      return res:text(output):send()
    end,
  })

  mcphub.add_resource('uv', {
    name = 'installed_packages',
    uri = 'jira://uv/pip/list',
    description = 'List of installed packages',
    handler = function(req, res)
      -- Execute jira issue list command (adjust the query as needed)
      local cmd = 'uv pip list'
      local output = vim.fn.system(cmd)

      -- Check if command was successful
      if vim.v.shell_error ~= 0 then
        return res:error('Failed to list packages: ' .. output)
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
