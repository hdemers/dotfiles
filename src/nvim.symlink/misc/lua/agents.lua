local M = {}

M.setup = function()
  vim.api.nvim_create_user_command(
    'AgentsPlans',
    M.show_plans,
    { desc = 'Show Agent Plans' }
  )
end

M.show_plans = function()
  local home = vim.fn.expand '~'

  require('snacks').picker.pick {
    title = 'Agent Plans',
    cwd = home,
    finder = 'proc',
    cmd = 'bash',
    args = {
      '-c',
      'fd --type f --extension md --hidden --full-path "plans" .claude/plans .gemini/tmp -X stat -c "%Y %n" | sort -nr',
    },
    format = 'file',
    formatters = {
      file = {
        filename_only = true,
      },
    },
    -- Provide a transform function to set the file field so the default open action works
    transform = function(item)
      local mtime, path = string.match(item.text, '^(%d+)%s+(.+)$')
      if mtime and path then
        item.cwd = home
        item.file = path

        -- Use snacks utility for relative time
        local reltime = require('snacks.picker.util').reltime(tonumber(mtime))
        -- Align it so the columns line up (reltime maxes out at ~14 chars "12 minutes ago")
        item.label = string.format('%-14s ', reltime)
      else
        -- Fallback if regex fails
        item.cwd = home
        item.file = item.text
      end
    end,
  }
end

return M
