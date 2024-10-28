return {
  {
    'stevearc/overseer.nvim',
    opts = {
      task_win = {
        max_width = 0.6,
      },
      component_aliases = {
        default = {
          { 'display_duration', detail_level = 2 },
          'on_output_summarize',
          'on_exit_set_status',
          'on_complete_notify',
          -- Removing this line will cause tasks to never be disposed.
          -- { 'on_complete_dispose', timeout = 3600 },
        },
      },
    },
    cmd = { 'OverseerRun', 'OverseerToggle', 'OverseerRunCmd' },
    keys = {
      {
        '<leader>rd',
        '<cmd>OverseerRun deploy-branch<CR>',
        desc = 'Overseer: [d]eploy branch',
      },
      {
        '<leader>ri',
        '<cmd>OverseerRun integrate<CR>',
        desc = 'Overseer: [i]ntegrate branch',
      },
      {
        '<leader>rs',
        '<cmd>OverseerToggle right<CR>',
        desc = 'Overseer: toggle [s]tatus',
      },
      {
        '<leader>rt',
        '<cmd>OverseerRun make-test<CR>',
        desc = 'Overseer: make [t]est',
      },
      {
        '<leader>rr',
        '<cmd>OverseerRun make-requirements<CR>',
        desc = 'Overseer: make [r]equirements',
      },
      {
        '<leader>rf',
        '<cmd>OverseerRun run-file<CR>',
        desc = 'Overseer: run [f]ile',
      },
      {
        '<leader>ro',
        '<cmd>OverseerQuickAction open float<CR>',
        desc = 'Overseer: show [o]utput',
      },
    },
    config = function(_, opts)
      require('overseer').setup(opts)
    end,
    init = function()
      -- Document key chains
      require('which-key').add {
        { '<leader>r', group = '[R]unner' },
      }

      local overseer = require 'overseer'
      overseer.load_template 'misc.run_file'
      overseer.load_template 'gh.deploy_branch'
      overseer.load_template 'gh.integrate'
      overseer.load_template 'gh.make_requirements'
      overseer.load_template 'gh.make_test'
    end,
  },
  {
    'OscarCreator/rsync.nvim',
    build = 'make',
    dependencies = 'nvim-lua/plenary.nvim',
    config = function()
      require('rsync').setup {
        sync_on_save = true,
      }
    end,
  },
  {
    'akinsho/toggleterm.nvim',
    version = '*',
    opts = {
      open_mapping = '<F12>',
      direction = 'vertical',
      size = 180,
    },
  },
}
