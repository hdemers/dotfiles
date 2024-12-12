return {
  {
    'github/copilot.vim',
    lazy = false,
    init = function()
      -- Set the highlight group for copilot suggestions
      local apply_highlight = function()
        vim.api.nvim_set_hl(0, 'CopilotSuggestion', {
          link = 'Whitespace',
        })
      end
      apply_highlight()
      vim.api.nvim_create_autocmd('ColorScheme', {
        pattern = 'solarized',
        group = vim.api.nvim_create_augroup('CustomColorscheme', { clear = false }),
        callback = apply_highlight,
      })
    end,
  },
  {
    'Aaronik/GPTModels.nvim',
    enabled = false,
    dependencies = {
      'MunifTanjim/nui.nvim',
      'nvim-telescope/telescope.nvim',
    },
    keys = {
      {
        '<leader>hc',
        ':GPTModelsChat<CR>',
        desc = 'ChatGPT: [h]elp [c]hat',
        mode = { 'n', 'v' },
      },
      -- {
      --   '<leader>ho',
      --   ':GPTModelsCode<CR>',
      --   desc = 'GPTModels: [h]elp c[o]de',
      --   mode = { 'n', 'v' },
      -- },
    },
  },
  {
    'yetone/avante.nvim',
    enabled = true,
    event = 'VeryLazy',
    lazy = false,
    version = false, -- set this if you want to always pull the latest change
    opts = {
      -- add any opts here
    },
    -- if you want to build from source then do `make BUILD_FROM_SOURCE=true`
    build = 'make',
    -- build = "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false" -- for windows
    dependencies = {
      'nvim-treesitter/nvim-treesitter',
      'stevearc/dressing.nvim',
      'nvim-lua/plenary.nvim',
      'MunifTanjim/nui.nvim',
      --- The below dependencies are optional,
      'nvim-tree/nvim-web-devicons', -- or echasnovski/mini.icons
      -- 'zbirenbaum/copilot.lua', -- for providers='copilot'
      {
        -- support for image pasting
        'HakonHarnes/img-clip.nvim',
        event = 'VeryLazy',
        opts = {
          -- recommended settings
          default = {
            embed_image_as_base64 = false,
            prompt_for_file_name = false,
            drag_and_drop = {
              insert_mode = true,
            },
            -- required for Windows users
            use_absolute_path = true,
          },
        },
      },
      -- {
      --   -- Make sure to set this up properly if you have lazy=true
      --   'MeanderingProgrammer/render-markdown.nvim',
      --   opts = {
      --     file_types = { 'markdown', 'Avante', 'quarto', 'rmd' },
      --   },
      --   ft = { 'markdown', 'Avante' },
      -- },
    },
    init = function()
      -- Document key chains
      require('which-key').add {
        { '<leader>a', group = '[A]I' },
      }
    end,
  },
}
