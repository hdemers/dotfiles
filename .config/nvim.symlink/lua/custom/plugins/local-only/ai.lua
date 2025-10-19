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
        keymap = {
          accept_and_goto = '<Tab>',
          accept = false,
          dismiss = '<Esc>',
        },
      },
    },
    config = function(_, opts)
      require('copilot').setup(opts)
    end,
  },
  {
    'coder/claudecode.nvim',
    dependencies = { 'folke/snacks.nvim' },
    enabled = true,
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
      {
        '<tab>',
        function()
          -- if there is a next edit, jump to it, otherwise apply it if any
          if not require('sidekick').nes_jump_or_apply() then
            return '<Tab>' -- fallback to normal tab
          end
        end,
        expr = true,
        desc = 'Goto/Apply Next Edit Suggestion',
      },
      {
        '<leader>aa',
        function()
          require('sidekick.cli').toggle { focus = true }
        end,
        desc = 'Sidekick Toggle CLI',
        mode = { 'n', 'v' },
      },
      {
        '<c-space>',
        function()
          require('sidekick.cli').toggle { name = 'claude', focus = true }
        end,
        desc = 'Sidekick Claude Toggle',
        mode = { 'n', 'x', 'i', 't' },
      },
      {
        '<leader>ag',
        function()
          require('sidekick.cli').toggle { name = 'grok', focus = true }
        end,
        desc = 'Sidekick Grok Toggle',
        mode = { 'n', 'v' },
      },
      {
        '<leader>ap',
        function()
          require('sidekick.cli').select_prompt()
        end,
        desc = 'Sidekick Ask Prompt',
        mode = { 'n', 'v' },
      },
    },
  },
}
