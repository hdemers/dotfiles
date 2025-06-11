local M = {}

local function setup_quarto_server()
  local mcphub = require 'mcphub'

  mcphub.add_tool('quarto', {
    name = 'render',
    description = 'Render a Quarto document',
    inputSchema = {
      type = 'object',
      properties = {
        path = {
          type = 'string',
          description = 'Path to the Quarto document to render',
        },
        format = {
          type = 'string',
          description = 'Optional output format (e.g. "html", "pdf"), defaults to "html"',
        },
      },
      required = { 'path' },
    },
    handler = function(req, res)
      local path = req.params.path
      local format = req.params.format or 'html'

      local cmd = 'distrobox enter -- quarto render ' .. vim.fn.shellescape(path)
      cmd = cmd .. ' --to ' .. vim.fn.shellescape(format)
      local output = vim.fn.system(cmd)

      -- Check if command was successful
      if vim.v.shell_error ~= 0 then
        return res:error('Failed to render document: ' .. output)
      end

      return res:text(output):send()
    end,
  })
end

-- Initialize the server when this module is loaded
function M.setup()
  setup_quarto_server()
end

return M
