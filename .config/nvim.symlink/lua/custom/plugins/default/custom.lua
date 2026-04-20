return {
  {
    name = 'ntfy',
    dir = '~/src/nvim/ntfy',
    config = function()
      local ntfy = require 'ntfy'
      ntfy.setup()
    end,
  },
  {
    name = 'misc',
    lazy = false,
    dir = '~/src/nvim/misc',
    config = function()
      -- Misc setup
      local misc = require 'misc'
      misc.setup()

      _G.MySimpleTabline = misc.simple_tabline
      vim.opt.tabline = '%!v:lua.MySimpleTabline()'

      vim.api.nvim_create_user_command('RsyncFile', function(opts)
        misc.rsync_current_file(opts.args, {})
      end, { nargs = '?', desc = 'Rsync current file to destination' })

      -- Agents setup
      local agents = require 'agents'
      agents.setup()

      vim.keymap.set(
        'n',
        '<localleader>sp',
        ':AgentsPlans<CR>',
        { desc = 'Search Agent Plans', silent = true }
      )

      -- Custom keymaps
      local wk = require 'which-key'
      wk.add {
        { '<leader>y', group = 'Yank' },
        { '<leader>yf', group = 'Yank File Paths' },
      }
      vim.keymap.set(
        'n',
        '<leader>yfa',
        ':let @+ = expand("%:p")<CR>',
        { desc = 'Copy absolute path' }
      )

      -- Yank relative path
      vim.keymap.set(
        'n',
        '<leader>yfr',
        ':let @+ = expand("%")<CR>',
        { desc = 'Copy relative path' }
      )

      -- Yank filename only
      vim.keymap.set(
        'n',
        '<leader>yfn',
        ':let @+ = expand("%:t")<CR>',
        { desc = 'Copy filename' }
      )
    end,
    init = function()
      -- vim.keymap.set('n', '<leader>go', function()
      --   local Terminal = require('toggleterm.terminal').Terminal
      --   Terminal:new({
      --     direction = 'vertical',
      --     cmd = 'gh pr create',
      --     hidden = false,
      --   }):open()
      -- end, { desc = 'Open PR' })

      -- Function to rename zellij tab based on current directory
      local function rename_zellij_tab()
        local cwd = vim.fn.getcwd()
        local title = vim.fn.fnamemodify(cwd, ':t') -- Get just the directory name
        local cmd = string.format(
          'nohup zellij action rename-tab %s >/dev/null 2>&1',
          vim.fn.shellescape(title)
        )
        vim.fn.system(cmd)
      end

      -- Rename tab on startup
      vim.defer_fn(rename_zellij_tab, 100)

      -- Rename tab when directory changes
      vim.api.nvim_create_autocmd('DirChanged', {
        callback = rename_zellij_tab,
        desc = 'Rename zellij tab when directory changes',
      })
    end,
  },
}
