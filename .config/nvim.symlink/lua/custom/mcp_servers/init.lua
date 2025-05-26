-- Initialize all custom MCP servers

local M = {}

function M.setup()
  -- Load Jira MCP Server
  require('custom.mcp_servers.jira').setup()
  require('custom.mcp_servers.uv').setup()
  require('custom.mcp_servers.make').setup()

  -- Add more custom MCP servers here as needed
  -- require('custom.mcp_servers.another_server').setup()
end

return M
