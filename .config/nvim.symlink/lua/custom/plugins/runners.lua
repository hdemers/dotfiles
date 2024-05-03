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
        '<leader>cjd',
        '<cmd>OverseerRun jenkins-deploy-branch<CR>',
        desc = 'Overseer: [j]enkins [d]eploy branch',
      },
      {
        '<leader>cji',
        '<cmd>OverseerRun jenkins-integrate<CR>',
        desc = 'Overseer: [j]enkins [i]ntegrate branch',
      },
      {
        '<leader>ot',
        '<cmd>OverseerToggle right<CR>',
        desc = 'Overseer: [t]oggle',
      },
    },
    config = function(_, opts)
      require('overseer').setup(opts)
    end,
    init = function()
      -- Document key chains
      require('which-key').register {
        ['<leader>o'] = { name = '[O]verseer', _ = 'which_key_ignore' },
        ['<leader>cj'] = { name = '[J]enkins', _ = 'which_key_ignore' },
      }

      local overseer = require 'overseer'

      overseer.register_template {
        name = 'jenkins-deploy-branch',
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
        name = 'jenkins-integrate',
        builder = function()
          return {
            cmd = { 'jenkins' },
            args = { 'integrate' },
            name = 'integrate',
          }
        end,
        desc = 'Integrate branch',
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
