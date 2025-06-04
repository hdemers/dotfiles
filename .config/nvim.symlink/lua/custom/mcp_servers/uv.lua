local M = {}

local function setup_uv_server()
  local mcphub = require 'mcphub'

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
    uri = 'uv://uv/pip/list',
    description = 'List of installed packages',
    handler = function(req, res)
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
  setup_uv_server()
end

return M
