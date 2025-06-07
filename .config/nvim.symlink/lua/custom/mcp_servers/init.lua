-- Initialize all custom MCP servers

local M = {}

function M.setup()
  -- Load Jira MCP Server
  require('custom.mcp_servers.jira').setup()
  require('custom.mcp_servers.uv').setup()
  require('custom.mcp_servers.make').setup()
  require('custom.mcp_servers.prompts').setup()
  require('custom.mcp_servers.git').setup()
  require('custom.mcp_servers.pytest').setup()
  require('custom.mcp_servers.notify').setup()

  -- Add more custom MCP servers here as needed
  -- require('custom.mcp_servers.another_server').setup()
end

return M
