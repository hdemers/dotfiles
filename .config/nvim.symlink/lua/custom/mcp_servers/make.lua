local M = {}

-- Add the Makefile describe tool
local function setup_make_server()
  local mcphub = require 'mcphub'

  -- Create a tool to execute Makefile targets
  mcphub.add_tool('make', {
    name = 'make_target',
    description = 'Run a Makefile target',
    inputSchema = {
      type = 'object',
      properties = {
        package = {
          type = 'string',
          description = 'Makefile target to run',
        },
      },
      required = { 'package' },
    },
    handler = function(req, res)
      local target = req.params.package

      local cmd = 'make ' .. target
      local output = vim.fn.system(cmd)

      -- Check if command was successful
      if vim.v.shell_error ~= 0 then
        return res:error('Failed to run ' .. target .. ': ' .. output)
      end

      return res:text(output):send()
    end,
  })

  mcphub.add_resource('make', {
    name = 'makefile_targets',
    uri = 'make://target/list',
    description = 'List of targets in the Makefile',
    handler = function(req, res)
      local targets = {}
      local seen = {} -- To avoid duplicates
      local pwd = vim.fn.getcwd()
      vim.notify('Reading ' .. pwd .. '/Makefile for targets', vim.log.levels.DEBUG)
      local file = io.open(pwd .. '/Makefile', 'r')
      if not file then
        -- For debugging, you might want a print here:
        -- print("Error: Could not open Makefile at " .. makefile_path)
        return {}
      end

      for line in file:lines() do
        -- Match .PHONY lines, allowing for leading whitespace
        -- e.g., "  .PHONY: .clean .build"
        local phony_targets_str = line:match '^[ \t]*%.PHONY%s*:%s*(.+)'
        if phony_targets_str then
          for target in phony_targets_str:gmatch '[%w_%.%-/]+' do
            if not seen[target] then
              table.insert(targets, target)
              seen[target] = true
            end
          end
        else
          -- Match regular target lines, allowing for leading whitespace
          -- e.g., "  .build: myobject.o"
          -- Target name itself is captured before the colon.
          -- The pattern is:
          -- ^[ \t]*        -- Start of line, optional leading spaces/tabs
          -- ([%w_%.%-/]+)  -- CAPTURE: Word chars, dot, hyphen, slash (target name)
          -- %s*:           -- Optional whitespace then a colon
          -- (?![:=])       -- NEGATIVE LOOKAHEAD: Not followed by another colon or an equals sign
          local target = line:match '^[ \t]*([%w_%.%-/]+)%s*:(?![:=])'
          if target and target ~= '.PHONY' and not seen[target] then
            table.insert(targets, target)
            seen[target] = true
          end
        end
      end
      file:close()
      table.sort(targets)

      return res:text(targets):send()
    end,
  })
end

-- Initialize the server when this module is loaded
function M.setup()
  setup_make_server()
end

return M
