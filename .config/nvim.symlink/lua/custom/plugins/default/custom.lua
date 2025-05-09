return {
  {
    name = 'arduino',
    dir = '~/src/nvim/arduino',
    dependencies = {
      'stevearc/overseer.nvim',
    },
    config = function()
      require('arduino').setup()

      local overseer = require 'overseer'
      overseer.load_template 'misc.upload_sketch'
      overseer.load_template 'misc.compile_sketch'
      overseer.load_template 'misc.monitor_sketch'
    end,
  },
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
      local misc = require 'misc'
      misc.setup()

      vim.keymap.set(
        'n',
        '<localleader>js',
        misc.start_ipython,
        { desc = 'Start IPython', silent = true }
      )

      _G.MySimpleTabline = misc.simple_tabline
      vim.opt.tabline = '%!v:lua.MySimpleTabline()'

      vim.api.nvim_create_user_command('RsyncFile', function(opts)
        misc.rsync_current_file(opts.args, {})
      end, { nargs = '?', desc = 'Rsync current file to destination' })

      vim.keymap.set(
        'n',
        '<localleader>bi',
        ':tabnew scratch/scratch.qmd | <CR>',
        { desc = 'Open interactive Quarto notebook', silent = true }
      )
    end,
  },
  {
    name = 'fidget-spinner',
    dir = '~/src/nvim/misc',
    dependencies = { 'j-hui/fidget.nvim' },
  },
}
