return {
  {
    'zbirenbaum/copilot.lua',
    dependencies = { 'copilotlsp-nvim/copilot-lsp' },
    cmd = 'Copilot',
    event = 'InsertEnter',
    opts = {
      panel = {
        auto_refresh = true,
      },
      suggestion = {
        auto_trigger = true,
        keymap = {
          accept = '<Tab>',
        },
      },
      nes = {
        enabled = false,
        auto_trigger = false,
        keymap = {
          accept_and_goto = '<C-p',
          accept = false,
          dismiss = '<Esc>',
        },
      },
    },
    config = function(_, opts)
      require('copilot').setup(opts)

      -- Setup keymap to open Copilot panel.
      vim.keymap.set('n', '<leader>ao', function()
        require('copilot.panel').toggle()
      end, { desc = 'Copilot Panel Toggle' })
    end,
  },
  {
    'coder/claudecode.nvim',
    dependencies = { 'folke/snacks.nvim' },
    enabled = false,
    config = true,
    keys = {
      { '<leader>ac', nil, desc = 'AI/Claude Code' },
      { '<leader>acc', '<cmd>ClaudeCode<cr>', desc = 'Toggle Claude' },
      -- { '<C-Space>', '<cmd>ClaudeCodeFocus<cr>', desc = 'Focus Claude' },
      { '<leader>acr', '<cmd>ClaudeCode --resume<cr>', desc = 'Resume Claude' },
      { '<leader>acC', '<cmd>ClaudeCode --continue<cr>', desc = 'Continue Claude' },
      { '<leader>acb', '<cmd>ClaudeCodeAdd %<cr>', desc = 'Add current buffer' },
      { '<leader>acs', '<cmd>ClaudeCodeSend<cr>', mode = 'v', desc = 'Send to Claude' },
      {
        '<leader>as',
        '<cmd>ClaudeCodeTreeAdd<cr>',
        desc = 'Add file',
        ft = { 'NvimTree', 'neo-tree', 'oil' },
      },
      -- Diff management
      { '<leader>aca', '<cmd>ClaudeCodeDiffAccept<cr>', desc = 'Accept diff' },
      { '<leader>acd', '<cmd>ClaudeCodeDiffDeny<cr>', desc = 'Deny diff' },
    },
    opts = {
      -- Server Configuration
      auto_start = true,
      log_level = 'info', -- "trace", "debug", "info", "warn", "error"
      terminal_cmd = nil, -- Custom terminal command (default: "claude")
      -- For local installations: "~/.claude/local/claude"
      -- For native binary: use output from 'which claude'

      -- Selection Tracking
      track_selection = true,
      visual_demotion_delay_ms = 50,

      -- Terminal Configuration
      terminal = {
        ---@module "snacks"
        ---@type snacks.win.Config|{}
        snacks_win_opts = {
          position = 'float',
          width = 0.5,
          height = 0.9,
          border = 'rounded',
          backdrop = 70,
          keys = {
            claude_hide = {
              '<C-Space>', -- Change above too
              function(self)
                self:hide()
              end,
              mode = 't',
              desc = 'Hide',
            },
          },
        },
      },
      diff_opts = {
        auto_close_on_accept = true,
        vertical_split = true,
        open_in_current_tab = false,
        keep_terminal_focus = false, -- If true, moves focus back to terminal after diff opens
      },
    },
  },
  {
    'folke/sidekick.nvim',
    opts = {
      -- add any options here
      cli = {
        win = { layout = 'float', float = { width = 0.6, height = 0.8 } },
        mux = {
          backend = 'zellij',
          enabled = true,
        },
      },
    },
    keys = {
      -- {
      --   '<tab>',
      --   function()
      --     -- if there is a next edit, jump to it, otherwise apply it if any
      --     if not require('sidekick').nes_jump_or_apply() then
      --       return '<Tab>' -- fallback to normal tab
      --     end
      --   end,
      --   expr = true,
      --   desc = 'Goto/Apply Next Edit Suggestion',
      -- },
      {
        '<c-space>',
        function()
          require('sidekick.cli').toggle { name = 'claude', focus = true }
        end,
        desc = 'Sidekick Claude Toggle',
        mode = { 'n', 'x', 'i', 't' },
      },
      {
        '<leader>aa',
        function()
          require('sidekick.cli').toggle()
        end,
        desc = 'Sidekick Toggle CLI',
      },
      {
        '<leader>as',
        function()
          require('sidekick.cli').select()
        end,
        -- Or to select only installed tools:
        -- require("sidekick.cli").select({ filter = { installed = true } })
        desc = 'Sidekick Select CLI',
      },
      {
        '<leader>at',
        function()
          require('sidekick.cli').send { msg = '{this}' }
        end,
        mode = { 'x', 'n' },
        desc = 'Send This',
      },
      {
        '<leader>af',
        function()
          require('sidekick.cli').send { msg = '{file}' }
        end,
        desc = 'Sidekick Send File',
      },
      {
        '<leader>av',
        function()
          require('sidekick.cli').send { msg = '{selection}' }
        end,
        mode = { 'x' },
        desc = 'Sidekick Send Visual Selection',
      },
      {
        '<leader>ap',
        function()
          require('sidekick.cli').prompt()
        end,
        mode = { 'n', 'x' },
        desc = 'Sidekick Select Prompt',
      },
      -- Example of a keybinding to open Claude directly
      {
        '<leader>ac',
        function()
          require('sidekick.cli').toggle { name = 'claude', focus = true }
        end,
        desc = 'Sidekick Toggle Claude',
      },
    },
  },
}
