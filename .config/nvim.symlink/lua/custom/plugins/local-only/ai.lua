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
    enabled = false,
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
    lazy = false,
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-treesitter/nvim-treesitter',
      'saghen/blink.cmp',
      'folke/snacks.nvim',
      'ravitemer/mcphub.nvim',
      'Davidyz/VectorCode',
      -- 'ravitemer/codecompanion-history.nvim',
    },
    -- stylua: ignore
    keys = {
      { '<leader>aoa', '<cmd>CodeCompanionChat<CR>', desc = 'CodeCompanion: chat', mode = { 'n', 'v' }, },
      { '<leader>aol', '<cmd>CodeCompanionChat Toggle<CR>', desc = 'CodeCompanion: toggle', },
      { '<leader>aod', '<cmd>CodeCompanionChat Add<CR>', desc = 'CodeCompanion: add selected code to chat', mode = { 'v' } },
      { '<leader>aoo', '<cmd>CodeCompanionActions<CR>', desc = 'CodeCompanion: open actions menu' },
      { '<leader>aoc', function() require("codecompanion").prompt("commit_staged") end, desc = 'CodeCompanion: commit staged files'},
      { '<leader>aop', function() require("codecompanion").prompt("open_pr") end, desc = 'CodeCompanion: open PR'},
    },
    opts = {
      display = {
        action_palette = {
          provider = 'default',
        },
        chat = {
          show_header_separator = true,
        },
      },
      adapters = {
        copilot = function()
          return require('codecompanion.adapters').extend('copilot', {
            schema = {
              model = {
                default = 'claude-sonnet-4',
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
          opts = {
            prompt_decorator = function(message, adapter, context)
              return string.format([[<prompt>%s</prompt>]], message)
            end,
          },
          tools = {
            opts = {
              auto_submit_errors = true,
              auto_submit_success = true,
            },
          },
        },
        inline = {
          adapter = 'copilot',
        },
      },
      extensions = {
        mcphub = {
          callback = 'mcphub.extensions.codecompanion',
          opts = {
            show_result_in_chat = true, -- Show mcp tool results in chat
            make_vars = true, -- Convert resources to #variables
            make_slash_commands = true, -- Add prompts as /slash commands
          },
        },
        vectorcode = {
          opts = { add_tool = true, add_slash_command = true, tool_opts = {} },
        },
        -- history = {
        --   enabled = true,
        --   opts = {
        --     -- Keymap to open history from chat buffer (default: gh)
        --     keymap = 'gh',
        --     -- Keymap to save the current chat manually (when auto_save is disabled)
        --     save_chat_keymap = 'sc',
        --     -- Save all chats by default (disable to save only manually using 'sc')
        --     auto_save = true,
        --     -- Number of days after which chats are automatically deleted (0 to disable)
        --     expiration_days = 0,
        --     -- Picker interface ("telescope" or "snacks" or "fzf-lua" or "default")
        --     picker = 'snacks',
        --     ---Automatically generate titles for new chats
        --     auto_generate_title = true,
        --     title_generation_opts = {
        --       ---Adapter for generating titles (defaults to active chat's adapter)
        --       adapter = nil, -- e.g "copilot"
        --       ---Model for generating titles (defaults to active chat's model)
        --       model = nil, -- e.g "gpt-4o"
        --     },
        --     ---On exiting and entering neovim, loads the last chat on opening chat
        --     continue_last_chat = false,
        --     ---When chat is cleared with `gx` delete the chat from history
        --     delete_on_clearing_chat = false,
        --     ---Directory path to save the chats
        --     dir_to_save = vim.fn.stdpath 'data' .. '/codecompanion-history',
        --     ---Enable detailed logging for history extension
        --     enable_logging = false,
        --   },
        -- },
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
      prompt_library = {
        ['Commit Staged'] = {
          strategy = 'chat',
          description = 'Commit the staged files',
          opts = {
            auto_submit = true,
            user_prompt = false,
            short_name = 'commit_staged',
          },
          prompts = {
            {
              role = 'system',
              content = 'You are an expert at writing conventional commit messages. Follow the user instructions closely.',
            },
            {
              role = 'user',
              content = function(_)
                local repo = vim.fn.system 'git rev-parse --show-toplevel'
                local branch = vim.fn.system 'git rev-parse --abbrev-ref HEAD'
                return '1. Write a commit message (DO NOT COMMIT just yet) for the files staged in repository '
                  .. repo
                  .. ' on branch '
                  .. branch
                  .. '2. Follow the conventional commit format.\n'
                  .. '3. Ask the user for the Jira commit ticket number. (DO NOT COMMIT just yet)\n'
                  .. '4. Add the ticket number on a line of its own at the end of the commit message. \n'
                  .. '5. Ask the user to review the commit message. \n'
                  .. '6. If the user approves the message, commit it!\n'
                  .. '7. Next, try pushing the branch to the remote\n'
                  .. '8. If the push fails, stop right there, do not try to resolve the error, inform the user.\n'
                  .. ' @mcp'
              end,
            },
          },
        },
        ['Open PR'] = {
          strategy = 'chat',
          description = 'Open PR',
          opts = {
            auto_submit = true,
            user_prompt = false,
            short_name = 'open_pr',
          },
          prompts = {
            {
              role = 'system',
              content = 'You are an expert at writing good PR description. Follow the user instructions closely.',
            },
            {
              role = 'user',
              content = function(_)
                local repo = vim.fn.system 'git rev-parse --show-toplevel'
                local remote_url = vim.fn.system 'git config --get remote.origin.url'
                local main_branch_name =
                  vim.fn.system 'git symbolic-ref refs/remotes/origin/HEAD | sed "s@^refs/remotes/origin/@@"'
                local branch = vim.fn.system 'git rev-parse --abbrev-ref HEAD'
                return string.format(
                  [[
Open a PR for branch '%s' in repository _%s_ (remote URL: %s). 

Follow these instructions closely:

1. If there's a template file in .github/PULL_REQUEST_TEMPLATE.md use it.
2. The commits part of this PR are those between HEAD and %s, use the `git_log_from_to` tool.
3. Use the commit's messages part of this PR as the basis for the PR description.
4. Use Markdown formatting for the PR description.
5. Ask the user for approval before opening the PR.
6. Once the PR has been opened, transition the associated ticket to "In Review".

@mcp
]],
                  branch,
                  repo,
                  remote_url,
                  main_branch_name
                )
              end,
            },
          },
        },
      },
    },
    config = function(_, opts)
      require('codecompanion').setup(opts)
      require('which-key').add {
        { '<leader>ao', group = 'CodeCompanion' },
      }
      require('codecompanion-processing-spinner'):init()
      require('codecompanion-fidget-spinner'):init()

      -- Add keymap for write, stage, diff, and CodeCompanion chat
      vim.keymap.set('n', '<leader>gd', function()
        -- Write the current buffer
        vim.cmd 'write'

        -- Stage the current file using fugitive
        vim.cmd 'Gwrite'

        -- Get the diff of the staged file
        local diff_output =
          vim.fn.system('git diff --cached ' .. vim.fn.shellescape(vim.fn.expand '%'))

        -- Store changes in local variable
        local changes = diff_output
        local filename = vim.fn.expand '%:t'

        -- Get context for the current buffer
        local context =
          require('codecompanion.utils.context').get(vim.api.nvim_get_current_buf(), {})

        -- Custom prompt for CodeCompanion
        local prompt = 'Create a checkpoint commit message for the file '
          .. filename
          .. ' having the following changes:\n\n'
          .. '```diff'
          .. changes
          .. '```\n\n'
          .. 'Then commit the changes and push the branch to the remote repository. '
          .. 'Do not interrupt the user. @mcp \n\n'

        -- Create chat with proper message structure for auto_submit
        local chat = require('codecompanion.strategies.chat').new {
          context = context,
          messages = {
            {
              role = require('codecompanion.config').constants.USER_ROLE,
              content = prompt,
            },
          },
          auto_submit = true,
        }

        vim.notify('AI checkpoint commit initiated in background', vim.log.levels.INFO)
      end, { desc = 'Git: stage and review changes with AI' })
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
      level = vim.log.levels.DEBUG,
      to_file = true,
      file_path = vim.fn.expand '~/mcphub.log',
    },
    config = function(_, opts)
      require('mcphub').setup(opts)
      -- Initialize custom MCP servers
      require('custom.mcp_servers').setup()
    end,
  },
  {
    'Davidyz/VectorCode',
    enabled = true,
    version = '*',
    build = 'uv tool upgrade "vectorcode[mcp,lsp]"',
    dependencies = { 'nvim-lua/plenary.nvim' },
    opts = {
      async_backend = 'lsp',
    },
    config = function(_, opts)
      require('vectorcode').setup(opts)
    end,
  },
}
