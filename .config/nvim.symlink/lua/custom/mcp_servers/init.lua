-- Initialize all custom MCP servers

local M = {}

function M.setup()
  require('custom.mcp_servers.jira').setup()
  require('custom.mcp_servers.uv').setup()
  require('custom.mcp_servers.make').setup()
  require('custom.mcp_servers.prompts').setup()
  require('custom.mcp_servers.git').setup()
  require('custom.mcp_servers.pytest').setup()
  require('custom.mcp_servers.notify').setup()
  require('custom.mcp_servers.quarto').setup()
end

return M
