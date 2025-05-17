return {
  {
    'zbirenbaum/copilot.lua',
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
    },
    config = function(_, opts)
      require('copilot').setup(opts)
    end,
  },
  {
    'yetone/avante.nvim',
    enabled = true,
    event = 'VeryLazy',
    lazy = false,
    version = false, -- set this if you want to always pull the latest change
    keys = {
      { '<leader>ava', ':AvanteAsk<CR>', desc = 'Avante: ask', mode = { 'n', 'v' } },
      { '<leader>avl', ':AvanteToggle<CR>', desc = 'Avante: toggle' },
      { '<leader>avc', ':AvanteChat<CR>', desc = 'Avante: chat' },
      { '<leader>avs', ':AvanteStop<CR>', desc = 'Avante: stop' },
      { '<leader>avn', ':AvanteChatNew<CR>', desc = 'Avante: new chat' },
      { '<leader>avf', ':AvanteFocus<CR>', desc = 'Avante: focus sidebar' },
      { '<leader>avm', ':AvanteModels<CR>', desc = 'Avante: model list' },
      { '<leader>avp', ':AvanteShowRepoMap<CR>', desc = 'Avante: show repo map' },
      { '<leader>avh', ':AvanteHistory<CR>', desc = 'Avante: show chat history' },
      { '<leader>avx', ':AvanteClear<CR>', desc = 'Avante: reset' },
    },
    opts = {
      provider = 'copilot',
      cursor_applying_provider = 'copilot',
      disabled_tools = {
        'list_files',
        'search_files',
        'read_file',
        'create_file',
        'rename_file',
        'delete_file',
        'create_dir',
        'rename_dir',
        'delete_dir',
        'bash',
      },
      copilot = {
        model = 'claude-3.7-sonnet',
        -- disable_tools = true,
      },
      behaviour = {
        auto_set_keymaps = false,
        enable_cursor_planning_mode = true,
      },
      hints = { enabled = false },
      -- The system_prompt type supports both a string and a function that returns a string. Using a function here allows dynamically updating the prompt with mcphub
      system_prompt = function()
        local hub = require('mcphub').get_hub_instance()
        return hub:get_active_servers_prompt()
      end,
      -- The custom_tools type supports both a list and a function that returns a list. Using a function here prevents requiring mcphub before it's loaded
      custom_tools = function()
        return {
          require('mcphub.extensions.avante').mcp_tool(),
        }
      end,
    },
    -- if you want to build from source then do `make BUILD_FROM_SOURCE=true`
    build = 'make',
    -- build = "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false" -- for windows
    dependencies = {
      'nvim-treesitter/nvim-treesitter',
      'stevearc/dressing.nvim',
      'nvim-lua/plenary.nvim',
      'MunifTanjim/nui.nvim',
      'ibhagwan/fzf-lua',
      'nvim-tree/nvim-web-devicons', -- or echasnovski/mini.icons
      'zbirenbaum/copilot.lua', -- for providers='copilot'
      'ravitemer/mcphub.nvim',
      { -- This is the blink-cmp-avante plugin. The dependency is reversed
        -- because it needs to be loaded before blink.cmp.
        'saghen/blink.cmp',
        dependencies = {
          'Kaiser-Yang/blink-cmp-avante',
          -- ... Other dependencies
        },
        opts = {
          sources = {
            -- Add 'avante' to the list
            default = { 'avante', 'lsp', 'path', 'buffer' },
            providers = {
              avante = {
                module = 'blink-cmp-avante',
                name = 'Avante',
                opts = {
                  -- options for blink-cmp-avante
                },
              },
            },
          },
        },
      },
    },
    config = function(_, opts)
      require('avante').setup(opts)
      require('which-key').add {
        { '<leader>av', group = 'Avante' },
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
      model = 'claude-3.7-sonnet-thought',
      mappings = {
        reset = {
          normal = '',
          insert = '',
        },
        complete = {
          insert = '<S-Tab>',
        },
      },
      prompts = {
        ReviewLibraryStagedChanges = {
          prompt = 'This code is part of a library. The API should not be broken. Review the staged files for any breaking changes and other issues. #git:staged',
          description = 'Review staged files for breaking changes',
          mapping = '<leader>acb',
        },
        BetterNames = {
          prompt = 'Please provide better names for the following variables and functions.',
          description = 'Improve names of variables and functions.',
          mapping = '<leader>acn',
        },
        Wording = {
          prompt = 'Please improve the grammar and wording of the following text.',
          description = 'Improve the grammar and wording.',
          mapping = '<leader>acw',
        },
      },
    },
    -- stylua: ignore
    keys = {
      { '<leader>aca', ':CopilotChat<CR>', desc = 'Copilot: chat', mode = { 'n', 'v' }, },
      { '<leader>acl', ':CopilotChatToggle<CR>', desc = 'Copilot: toggle', },
      { '<leader>ace', ':CopilotChatExplain<CR>', desc = 'Copilot: explain', mode = { 'n', 'v' }, },
      { '<leader>acc', ':CopilotChatCommit<CR>', desc = 'Copilot: commit', mode = { 'n', 'v' }, },
      { '<leader>acd', ':CopilotChatDocs<CR>', desc = 'Copilot: document', mode = { 'n', 'v' }, },
      { '<leader>acf', ':CopilotChatFix<CR>', desc = 'Copilot: fix', mode = { 'n', 'v' }, },
      { '<leader>aco', ':CopilotChatOptimize<CR>', desc = 'Copilot: optimize', mode = { 'n', 'v' }, },
      { '<leader>acp', ':CopilotChatReview<CR>', desc = 'Copilot: review', mode = { 'n', 'v' }, },
      { '<leader>acu', ':CopilotChatTests<CR>', desc = 'Copilot: tests', mode = { 'n', 'v' }, },
      { '<leader>acx', ':CopilotChatReset<CR>', desc = 'Copilot: reset', mode = { 'n', 'v' }, },
    },
    config = function(_, opts)
      require('CopilotChat').setup(opts)

      require('which-key').add {
        { '<leader>ac', group = 'CopilotChat' },
      }
    end,
  },
  {
    'olimorris/codecompanion.nvim',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-treesitter/nvim-treesitter',
      'ravitemer/mcphub.nvim',
      'saghen/blink.cmp',
    },
    -- stylua: ignore
    keys = {
      { '<leader>aoa', '<cmd>CodeCompanionChat<CR>', desc = 'CodeCompanion: chat', mode = { 'n', 'v' }, },
      { '<leader>aol', '<cmd>CodeCompanionChat Toggle<CR>', desc = 'CodeCompanion: toggle', },
      { '<leader>aod', '<cmd>CodeCompanionChat AddCR>', desc = 'CodeCompanion: add selected code to chat', mode = { 'v' } },
    },
    opts = {
      adapters = {
        copilot = function()
          return require('codecompanion.adapters').extend('copilot', {
            schema = {
              model = {
                default = 'claude-3.7-sonnet',
              },
            },
          })
        end,
        gemini = function()
          return require('codecompanion.adapters').extend('gemini', {
            schema = {
              model = {
                default = 'gemini-2.5-pro',
              },
            },
          })
        end,
      },
      strategies = {
        chat = {
          adapter = 'copilot',
          tools = {},
        },
        inline = {
          adapter = 'copilot',
        },
      },
      display = {
        action_palette = {
          provider = 'default',
        },
      },
      extensions = {
        mcphub = {
          callback = 'mcphub.extensions.codecompanion',
          opts = {
            make_vars = true,
            make_slash_commands = true,
            show_result_in_chat = true,
          },
        },
      },
      send = {
        callback = function(chat)
          vim.cmd 'stopinsert'
          chat:add_buf_message { role = 'llm', content = '' }
          chat:submit()
        end,
        index = 1,
        description = 'Send',
      },
    },
    config = function(_, opts)
      require('codecompanion').setup(opts)
      require('which-key').add {
        { '<leader>ao', group = 'CodeCompanion' },
      }
      require('codecompanion-processing-spinner'):init()
      require('codecompanion-fidget-spinner'):init()
    end,
  },
  {
    'ravitemer/mcphub.nvim',
    dependencies = {
      'nvim-lua/plenary.nvim',
      -- 'yetone/avante.nvim',
      -- 'olimorris/codecompanion.nvim',
    },
    -- comment the following line to ensure hub will be ready at the earliest
    -- cmd = 'MCPHub', -- lazy load by default
    -- build = 'npm install -g mcp-hub@latest', -- Installs required mcp-hub npm module
    -- uncomment this if you don't want mcp-hub to be available globally or can't use -g
    build = 'bundled_build.lua', -- Use this and set use_bundled_binary = true in opts  (see Advanced configuration)
    opts = {
      use_bundled_binary = true,
      auto_approve = true, -- Auto approve mcp tool calls
      auto_toggle_mcp_servers = true, -- Let LLMs start and stop MCP servers automatically
      extensions = {
        avante = {
          make_slash_commands = true, -- make /slash commands from MCP server prompts
        },
      },
    },
    config = function(_, opts)
      require('mcphub').setup(opts)
    end,
  },
}
