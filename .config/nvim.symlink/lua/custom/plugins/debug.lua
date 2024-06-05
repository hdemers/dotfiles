-- debug.lua
--
-- Shows how to use the DAP plugin to debug your code.
--
-- Primarily focused on configuring the debugger for Go, but can
-- be extended to other languages as well. That's why it's called
-- kickstart.nvim and not kitchen-sink.nvim ;)

return {
  {
    'mfussenegger/nvim-dap',
    dependencies = {
      -- Creates a beautiful debugger UI
      'rcarriga/nvim-dap-ui',

      -- Required dependency for nvim-dap-ui
      'nvim-neotest/nvim-nio',

      -- Installs the debug adapters for you
      'williamboman/mason.nvim',
      'jay-babu/mason-nvim-dap.nvim',

      -- Add your own debuggers here
      'mfussenegger/nvim-dap-python',
    },
    config = function()
      local dap = require 'dap'
      local dapui = require 'dapui'

      require('mason-nvim-dap').setup {
        -- Makes a best effort to setup the various debuggers with
        -- reasonable debug configurations
        automatic_installation = true,

        -- You can provide additional configuration to the handlers,
        -- see mason-nvim-dap README for more information
        handlers = {},

        -- You'll need to check that you have the required things installed
        -- online, please don't ask me how to install them :)
        ensure_installed = {
          -- Update this to ensure that you have the debuggers for the langs you want
          'python',
        },
      }

      -- Document key chains
      require('which-key').register {
        ['<leader>cd'] = { name = '[D]ebug', _ = 'which_key_ignore' },
      }
      vim.keymap.set(
        'n',
        '<leader>cdc',
        dap.continue,
        { desc = 'Debug: start/[c]ontinue' }
      )
      vim.keymap.set('n', '<leader>cdi', dap.step_into, { desc = 'Debug: step [i]nto' })
      vim.keymap.set('n', '<leader>cds', dap.step_over, { desc = 'Debug: [s]tep over' })
      vim.keymap.set('n', '<leader>cdo', dap.step_out, { desc = 'Debug: step [o]ut' })
      vim.keymap.set(
        'n',
        '<leader>cdb',
        dap.toggle_breakpoint,
        { desc = 'Debug: Toggle [b]reakpoint' }
      )
      vim.keymap.set('n', '<leader>cdB', function()
        dap.set_breakpoint(vim.fn.input 'Breakpoint condition: ')
      end, { desc = 'Debug: Set [B]reakpoint' })
      -- Load a config from .vscode/launch.js
      vim.keymap.set('n', '<leader>cdl', function()
        require('dap.ext.vscode').load_launchjs()
      end, { desc = 'Debug: [l]load .vscode/launch.js' })

      -- Dap UI setup
      -- For more information, see |:help nvim-dap-ui|
      dapui.setup {
        -- Set icons to characters that are more likely to work in every terminal.
        --    Feel free to remove or use ones that you like more! :)
        --    Don't feel like these are good choices.
        icons = { expanded = '▾', collapsed = '▸', current_frame = '*' },
        controls = {
          icons = {
            pause = '⏸',
            play = '▶',
            step_into = '',
            step_over = '',
            step_out = '',
            step_back = '',
            run_last = '⟲',
            terminate = '⏹',
            disconnect = '✗',
          },
        },
        layouts = {
          {
            elements = {
              -- Other DAP UI elements you want to include in the layout
              'scopes',
              'breakpoints',
              'stacks',
              'watches',
            },
            size = 60,
            position = 'left',
          },
          {
            elements = {
              'console',
            },
            size = 130,
            position = 'right',
          },
          {
            elements = {
              'repl',
            },
            size = 80,
            position = 'left',
          },
        },
      }

      -- Toggle to see last session result. Without this, you can't see session output in case of unhandled exception.
      -- vim.keymap.set(
      --   'n',
      --   '<F7>',
      --   dapui.toggle,
      --   { desc = 'Debug: See last session result.' }
      -- )

      -- Function to open the current buffer in a new tab
      local function bufferTabOpen()
        -- Get the current cursor position
        local cur_pos = vim.api.nvim_win_get_cursor(0) -- Returns a table {row, col}

        -- Open the current buffer in a new tab
        -- Get the current buffer's file path
        local cur_buf_path = vim.api.nvim_buf_get_name(0)
        -- Command to open a new tab and edit the current buffer's file
        vim.cmd('tabnew ' .. cur_buf_path)
        vim.api.nvim_win_set_width(0, 220)

        -- Step 3: Set the cursor to the original position in the new tab
        -- Wait for the new tab to fully open and then set the cursor position
        vim.defer_fn(function()
          vim.api.nvim_win_set_cursor(0, cur_pos)
        end, 0) -- 0 ms delay to defer the function until after the command has completed
      end

      dap.listeners.after.event_initialized['dapui_config'] = function()
        bufferTabOpen()
        dapui.open()
      end
      dap.listeners.before.event_terminated['dapui_config'] = function()
        vim.cmd 'tabclose'
        dapui.close()
      end
      dap.listeners.before.event_exited['dapui_config'] = function()
        dapui.close()
      end

      vim.keymap.set('n', '<leader>cdt', function()
        require('neotest').run.run { strategy = 'dap' }
      end, { desc = 'Debug: nearest unit [t]est' })

      -- Install Python specific config
      local dap_python = require 'dap-python'
      dap_python.setup '~/.virtualenvs/debugpy/bin/python'
      dap_python.test_runner = 'pytest'
    end,
  },
  {
    'nvim-neotest/neotest',
    dependencies = {
      'nvim-neotest/nvim-nio',
      'nvim-lua/plenary.nvim',
      'antoinemadec/FixCursorHold.nvim',
      'nvim-treesitter/nvim-treesitter',
      'nvim-neotest/neotest-python',
    },
    config = function(_, opts)
      local neotest_ns = vim.api.nvim_create_namespace 'neotest'
      vim.diagnostic.config({
        virtual_text = {
          format = function(diagnostic)
            -- Replace newline and tab characters with space for more compact diagnostics
            local message = diagnostic.message
              :gsub('\n', ' ')
              :gsub('\t', ' ')
              :gsub('%s+', ' ')
              :gsub('^%s+', '')
            return message
          end,
        },
      }, neotest_ns)

      if package.loaded.trouble then
        opts.consumers = opts.consumers or {}
        -- Refresh and auto close trouble after running tests
        opts.consumers.trouble = function(client)
          client.listeners.results = function(adapter_id, results, partial)
            if partial then
              return
            end
            local tree = assert(client:get_position(nil, { adapter = adapter_id }))

            local failed = 0
            for pos_id, result in pairs(results) do
              if result.status == 'failed' and tree:get_key(pos_id) then
                failed = failed + 1
              end
            end
            vim.schedule(function()
              local trouble = require 'trouble'
              if trouble.is_open() then
                trouble.refresh()
                if failed == 0 then
                  trouble.close()
                end
              end
            end)
            return {}
          end
        end
      end
      -- @diagnostic disable-next-line: missing-fields
      require('neotest').setup {
        -- Can be a list of adapters like what neotest expects,
        -- or a list of adapter names,
        -- or a table of adapter names, mapped to adapter configs.
        -- The adapter will then be automatically loaded with the config.
        adapters = {
          require 'neotest-python' {
            dap = { justMyCode = false },
            runner = 'pytest',
          },
        },
        -- Example for loading neotest-go with a custom config
        -- adapters = {
        --   ["neotest-go"] = {
        --     args = { "-tags=integration" },
        --   },
        -- },
        status = { virtual_text = true },
        output = { open_on_run = true },
        quickfix = {
          -- open = function()
          --   if package.loaded.trouble then
          --     require('trouble').open { mode = 'quickfix', focus = false }
          --   else
          --     vim.cmd 'copen'
          --   end
          -- end,
        },
        icons = {
          failed = '✗',
          passed = '✔',
          pending = '⧗',
          error = '!',
          running = '⟲',
          unknown = '?',
        },
      }
    end,
    init = function()
      -- Document key chains
      require('which-key').register {
        ['<leader>t'] = { name = 'Unit [t]est', _ = 'which_key_ignore' },
      }
    end,
    -- stylua: ignore
    keys = {
      {
        "<leader>tt",
        function()
          require("neotest").run.run(vim.fn.expand("%"))
        end,
        desc = "Neotest: run file"
      },
      {
        "<leader>tT",
        function() require("neotest").run.run(vim.uv.cwd()) end,
        desc = "Neotest: run all test files"
      },
      {
        "<leader>tr",
        function() require("neotest").run.run() end,
        desc = "Neotest: run nearest"
      },
      {
        "<leader>tl",
        function() require("neotest").run.run_last() end,
        desc = "Neotest: run last"
      },
      {
        "<leader>ts",
        function() require("neotest").summary.toggle() end,
        desc = "Neotest: [t]oggle [s]ummary"
      },
      {
        "<leader>to",
        function()
          require("neotest").output.open({ enter = true, auto_close = true })
        end,
        desc = "Neotest: [t]oggle [o]utput"
      },
      {
        "<leader>tO",
        function()
          require("neotest").output_panel.toggle()
        end,
        desc = "Neotest: [t]oggle [O]utput panel"
      },
      {
        "<leader>tS",
        function() require("neotest").run.stop() end,
        desc = "Neotest: [S]top"
      },
    },
  },
}
