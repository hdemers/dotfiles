return {
  {
    'stevearc/overseer.nvim',
    opts = {
      task_win = {
        max_width = 0.6,
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
        ['<leader>cj'] = { name = '[j]enkins', _ = 'which_key_ignore' },
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
