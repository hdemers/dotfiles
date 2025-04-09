return {
  {
    'stevearc/overseer.nvim',
    opts = {
      task_win = {
        width = 0.6,
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
        function()
          local filetype = vim.bo.filetype
          local file_types = { 'python', 'java' }

          if vim.tbl_contains(file_types, filetype) then
            vim.cmd 'OverseerRun deploy-branch'
          elseif filetype == 'arduino' then
            vim.cmd 'ArduinoRun'
          end
        end,
        desc = 'Deploy branch',
      },
      {
        '<leader>rD',
        function()
          local filetype = vim.bo.filetype
          local file_types = { 'python', 'java' }

          if vim.tbl_contains(file_types, filetype) then
            vim.cmd 'OverseerRun deploy'
          elseif filetype == 'arduino' then
            vim.cmd 'ArduinoRun'
          end
        end,
        desc = 'Deploy',
      },
      {
        '<leader>rc',
        function()
          local filetype = vim.bo.filetype
          if filetype == 'arduino' then
            vim.cmd 'ArduinoStop'
          end
        end,
        desc = 'Cancel',
      },
      {
        '<leader>ri',
        function()
          local filetype = vim.bo.filetype
          local file_types = { 'python', 'java' }

          if vim.tbl_contains(file_types, filetype) then
            vim.cmd 'OverseerRun integrate'
          elseif filetype == 'arduino' then
            require('overseer').run_template { name = 'compile-sketch' }
          end
        end,
        desc = 'Integrate',
      },
      {
        '<leader>rs',
        '<cmd>OverseerToggle right<CR>',
        desc = 'Overseer toggle status',
      },
      {
        '<leader>rt',
        '<cmd>OverseerRun make-test<CR>',
        desc = 'Make test',
        ft = 'python',
      },
      {
        '<leader>rr',
        '<cmd>OverseerRun make-requirements<CR>',
        desc = 'Make requirements',
        ft = 'python',
      },
      {
        '<leader>rf',
        '<cmd>OverseerRun run-file<CR>',
        desc = 'Run file',
      },
      {
        '<leader>ro',
        '<cmd>OverseerQuickAction open float<CR>',
        desc = 'Overseer show output',
      },
    },
    config = function(_, opts)
      require('overseer').setup(opts)
    end,
    init = function()
      -- Document key chains
      local wk = require 'which-key'
      wk.add {
        { '<leader>r', group = 'Runner', icon = { icon = '', color = 'green' } },
      }

      local overseer = require 'overseer'
      overseer.load_template 'misc.run_file'
      overseer.load_template 'misc.test_task'
      overseer.load_template 'gh.deploy_branch'
      overseer.load_template 'gh.deploy'
      overseer.load_template 'gh.integrate'
      overseer.load_template 'gh.make_requirements'
      overseer.load_template 'gh.make_test'
    end,
  },
  {
    'akinsho/toggleterm.nvim',
    version = '*',
    opts = {
      open_mapping = [[<c-\>]],
      direction = 'vertical',
      size = 180,
      shading_factor = 0.75,
    },
    cmd = { 'ToggleTerm' },
    keys = {
      {
        [[<c-\>]],
      },
      {
        '<leader>bd',
        function()
          local Terminal = require('toggleterm.terminal').Terminal
          local box_name = os.getenv 'DBX_CONTAINER_NAME'
          Terminal:new({
            direction = 'vertical',
            cmd = 'distrobox enter ' .. box_name .. ' -- zsh',
            hidden = false,
            float_opts = { width = 60, height = 30 },
          }):open()
        end,
        desc = '[b]uffer terminal into [d]istrobox',
      },
    },
  },
}
