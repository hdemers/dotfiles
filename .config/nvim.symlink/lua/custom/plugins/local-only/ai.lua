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
          accept_and_goto = '<Leader>p',
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
    'folke/sidekick.nvim',
    enabled = false,
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
