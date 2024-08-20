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

      overseer.register_template {
        name = 'deploy-branch',
        builder = function()
          return {
            cmd = { 'jenkins' },
            args = { 'deploy-branch' },
            name = 'deploy-branch',
          }
        end,
        desc = 'Deploy branch',
      }
      overseer.register_template {
        name = 'integrate',
        builder = function()
          return {
            cmd = { 'jenkins' },
            args = { 'integrate' },
            name = 'integrate',
          }
        end,
        desc = 'Integrate branch',
      }
      overseer.register_template {
        name = 'make-test',
        builder = function()
          return {
            cmd = { 'make' },
            args = { 'test' },
            name = 'make-test',
          }
        end,
        desc = 'Run make test',
      }
      overseer.register_template {
        name = 'make-requirements',
        builder = function()
          return {
            cmd = { 'make' },
            args = { 'requirements.txt' },
            name = 'make-requirements',
          }
        end,
        desc = 'Run make requirements.txt',
      }
    end,
  },
  {
    'KenN7/vim-arsync',
    dependencies = 'prabirshrestha/async.vim',
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
