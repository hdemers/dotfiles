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
        desc = 'ChatGPT: help chat',
        mode = { 'n', 'v' },
      },
      -- {
      --   '<leader>ho',
      --   ':GPTModelsCode<CR>',
      --   desc = 'GPTModels: help code',
      --   mode = { 'n', 'v' },
      -- },
    },
  },
  {
    'yetone/avante.nvim',
    enabled = false,
    event = 'VeryLazy',
    lazy = false,
    version = false, -- set this if you want to always pull the latest change
    opts = {
      provider = 'copilot',
      vendors = {
        ollama = {
          __inherited_from = 'openai',
          api_key_name = '',
          endpoint = 'http://127.0.0.1:11434/v1',
          model = 'deepseek-r1:8b',
        },
      },
    },
    -- if you want to build from source then do `make BUILD_FROM_SOURCE=true`
    build = 'make',
    -- build = "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false" -- for windows
    dependencies = {
      'nvim-treesitter/nvim-treesitter',
      'stevearc/dressing.nvim',
      'nvim-lua/plenary.nvim',
      'MunifTanjim/nui.nvim',
      'echasnovski/mini.pick',
      'ibhagwan/fzf-lua',
      'nvim-telescope/telescope.nvim',
      'hrsh7th/nvim-cmp',
      'nvim-tree/nvim-web-devicons', -- or echasnovski/mini.icons
      'zbirenbaum/copilot.lua', -- for providers='copilot'
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
  {
    'CopilotC-Nvim/CopilotChat.nvim',
    dependencies = {
      { 'github/copilot.vim' }, -- or zbirenbaum/copilot.lua
      { 'nvim-lua/plenary.nvim', branch = 'master' }, -- for curl, log and async functions
    },
    build = 'make tiktoken', -- Only on MacOS or Linux
    opts = {
      -- See Configuration section for options
    },
    keys = {
      {
        '<leader>aa',
        ':CopilotChat<CR>',
        desc = 'Copilot: ch[a]t',
        mode = { 'n', 'v' },
      },
      {
        '<leader>al',
        ':CopilotChatToggle<CR>',
        desc = 'Copilot: togg[l]e',
      },
      {
        '<leader>ae',
        ':CopilotChatExplain<CR>',
        desc = 'Copilot: [e]xplain',
        mode = { 'n', 'v' },
      },
      {
        '<leader>ac',
        ':CopilotChatCommit<CR>',
        desc = 'Copilot: [c]ommit',
        mode = { 'n', 'v' },
      },
      {
        '<leader>ad',
        ':CopilotChatDocs<CR>',
        desc = 'Copilot: [d]ocument',
        mode = { 'n', 'v' },
      },
      {
        '<leader>af',
        ':CopilotChatFix<CR>',
        desc = 'Copilot: [f]ix',
        mode = { 'n', 'v' },
      },
      {
        '<leader>ao',
        ':CopilotChatOptimize<CR>',
        desc = 'Copilot: [o]ptimize',
        mode = { 'n', 'v' },
      },
      {
        '<leader>ar',
        ':CopilotChatReview<CR>',
        desc = 'Copilot: [r]eview',
        mode = { 'n', 'v' },
      },
      {
        '<leader>at',
        ':CopilotChatTests<CR>',
        desc = 'Copilot: [t]ests',
        mode = { 'n', 'v' },
      },
      {
        '<leader>ax',
        ':CopilotChatReset<CR>',
        desc = 'Copilot: reset',
        mode = { 'n', 'v' },
      },
    },
  },
  {
    'Davidyz/VectorCode',
    -- version = '*', -- optional, depending on whether you're on nightly or release
    -- build = 'uv tool upgrade vectorcode', -- optional but recommended if you set `version = "*"`
    dependencies = { 'nvim-lua/plenary.nvim' },
  },
  {
    'olimorris/codecompanion.nvim',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-treesitter/nvim-treesitter',
      'Davidyz/VectorCode',
    },
    opts = {
      strategies = {
        chat = {
          adapter = 'gemini',
        },
        inline = {
          adapter = 'gemini',
        },
      },
    },
    config = function(_, opts)
      -- Extends `opts` 'strategies.chat`'
      opts.strategies.chat.tools = {
        vectorcode = {
          description = 'Run VectorCode to retrieve the project context.',
          callback = require('vectorcode.integrations').codecompanion.chat.make_tool(),
        },
      }
      require('codecompanion').setup(opts)
    end,
  },
}
