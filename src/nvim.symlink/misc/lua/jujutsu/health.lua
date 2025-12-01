-- vim: ts=2 sts=2 sw=2 et
-- jujutsu/health.lua - Health check for :checkhealth jujutsu

local M = {}

function M.check()
  vim.health.start 'jujutsu.nvim'

  -- Check jj is installed
  if vim.fn.executable 'jj' == 0 then
    vim.health.error "'jj' not found in PATH"
  else
    local version = vim.fn.system 'jj --version'
    vim.health.ok("'jj' found: " .. vim.trim(version))
  end

  -- Check optional Snacks dependency
  local has_snacks = pcall(require, 'snacks')
  if has_snacks then
    vim.health.ok "'snacks.nvim' found - ANSI colorization enabled"
  else
    vim.health.warn "'snacks.nvim' not found - ANSI colorization disabled"
  end
end

return M
