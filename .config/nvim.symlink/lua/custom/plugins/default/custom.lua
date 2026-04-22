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

      local function zellij_tab_title_is_locked()
        if vim.env.ZELLIJ == nil then
          return false
        end

        local session_name = vim.env.ZELLIJ_SESSION_NAME or 'default'
        local cache_dir = vim.env.XDG_CACHE_HOME or (vim.env.HOME .. '/.cache')
        local lock_file = cache_dir .. '/zellij-tab-title-locks/' .. session_name

        if vim.fn.filereadable(lock_file) == 0 then
          return false
        end

        local tab_info = vim.fn.systemlist('zellij action current-tab-info 2>/dev/null')
        if vim.v.shell_error ~= 0 then
          return false
        end

        local tab_id = nil
        for _, line in ipairs(tab_info) do
          tab_id = line:match('^id:%s*(%S+)$')
          if tab_id ~= nil then
            break
          end
        end

        if tab_id == nil then
          return false
        end

        local locks = vim.fn.readfile(lock_file)
        for _, line in ipairs(locks) do
          if line == tab_id then
            return true
          end
        end

        return false
      end

      -- Function to rename zellij tab based on current directory
      local function rename_zellij_tab()
        if zellij_tab_title_is_locked() then
          return
        end

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
