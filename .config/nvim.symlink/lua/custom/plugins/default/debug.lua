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
      {
        'rcarriga/nvim-dap-ui',
        dependencies = { 'nvim-neotest/nvim-nio' },
        keys = {
          {
            '<leader>de',
            function()
              require('dapui').eval()
            end,
            desc = 'Eval',
            mode = { 'n', 'v' },
          },
        },
        opts = {
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
                -- 'breakpoints',
                'stacks',
                -- 'watches',
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
        },
        config = function(_, opts)
          local dap = require 'dap'
          local dapui = require 'dapui'

          dapui.setup(opts)

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
        end,
      },

      -- Installs the debug adapters for you
      'mason-org/mason.nvim',
      {
        'jay-babu/mason-nvim-dap.nvim',
        dependencies = 'mason.nvim',
        cmd = { 'DapInstall', 'DapUninstall' },
        opts = {
          -- Makes a best effort to setup the various debuggers with
          -- reasonable debug configurations
          automatic_installation = true,

          -- You can provide additional configuration to the handlers,
          -- see mason-nvim-dap README for more information
          handlers = { python = function() end },

          -- You'll need to check that you have the required things installed
          -- online, please don't ask me how to install them :)
          ensure_installed = {
            'python',
          },
        },
      },

      {
        'mfussenegger/nvim-dap-python',
        enabled = false,
        config = function()
          -- Install Python specific config
          local dap_python = require 'dap-python'
          local root = vim.env.MASON or (vim.fn.stdpath 'data' .. '/mason')
          local path = root .. '/packages/debugpy/venv/bin/python'
          dap_python.setup(path, {
            -- include_configs = true,
            -- console = 'integratedTerminal',
            -- pythonPath = nil,
          })
          dap_python.test_runner = 'pytest'
        end,
      },
      'nvim-neotest/neotest',
    },
    -- stylua: ignore
    keys = {
      { '<leader>dB', function() require('dap').set_breakpoint(vim.fn.input 'Breakpoint condition: ') end, desc = 'Breakpoint condition', },
      { '<leader>db', function() require('dap').toggle_breakpoint() end, desc = 'Toggle breakpoint', },
      { '<leader>dc', function() require('dap').continue() end, desc = 'Continue', },
      { '<leader>da', function() require('dap').continue { before = get_args } end, desc = 'Run with args', },
      { '<leader>dC', function() require('dap').run_to_cursor() end, desc = 'Run to cursor', },
      { '<leader>dg', function() require('dap').goto_() end, desc = 'Go to line (no execute)', },
      { '<leader>di', function() require('dap').step_into() end, desc = 'Step into', },
      { '<leader>dj', function() require('dap').down() end, desc = 'Down', },
      { '<leader>dk', function() require('dap').up() end, desc = 'Up', },
      { '<leader>dl', function() require('dap').run_last() end, desc = 'Run last', },
      { '<leader>dO', function() require('dap').step_out() end, desc = 'Step out', },
      { '<leader>do', function() require('dap').step_over() end, desc = 'Step over', },
      { '<leader>dp', function() require('dap').pause() end, desc = 'Pause', },
      { '<leader>dr', function() require('dap').repl.toggle() end, desc = 'Toggle repl', },
      { '<leader>ds', function() require('dap').session() end, desc = 'Session', },
      { '<leader>dq', function() require('dap').terminate() end, desc = 'Terminate', },
      { '<leader>dw', function() require('dap.ui.widgets').hover() end, desc = 'Widgets', },
      { '<leader>dt', function() require('neotest').run.run { strategy = 'dap' } end, desc = 'Debug: nearest unit [t]est', },
      { '<leader>dT', function() require('neotest').run.run { vim.uv.cwd(), strategy = 'dap' } end, desc = 'Debug: all test files', },
    },
    config = function()
      -- Document key chains
      require('which-key').add {
        { '<leader>d', group = 'Debug' },
      }

      -- setup dap config by VSCode launch.json file
      local vscode = require 'dap.ext.vscode'
      local _filetypes = require 'mason-nvim-dap.mappings.filetypes'
      local filetypes = vim.tbl_deep_extend('force', _filetypes, {
        ['node'] = { 'javascriptreact', 'typescriptreact', 'typescript', 'javascript' },
        ['pwa-node'] = {
          'javascriptreact',
          'typescriptreact',
          'typescript',
          'javascript',
        },
      })
      local json = require 'plenary.json'
      vscode.json_decode = function(str)
        return vim.json.decode(json.json_strip_comments(str))
      end

      local dap = require 'dap'
      dap.adapters.quarto = {
        type = 'server',
        port = 5678,
      }
      dap.configurations.quarto = {
        {
          type = 'quarto',
          name = 'Attach to debugger from Quarto notebook',
          request = 'attach',
          mode = 'auto',
          -- This is the default, but you can set it to "auto" or "manual"
          -- to control when the debugger starts.
          auto_open_console = true,
          console = 'integratedTerminal',
          use_python_path = true,
        },
      }

      dap.configurations.python = {
        {
          type = 'python',
          request = 'attach',
          name = 'Attach to running process',
          connect = {
            port = 5678,
            host = '0.0.0.0',
          },
          pathMappings = {
            {
              localRoot = '/run/host/var/home/hdemers',
              remoteRoot = '/var/home/hdemers',
            },
          },
          justMyCode = false,
          -- logToFile = true,
          -- debugOptions = { 'RedirectOutput' },
        },
        {
          type = 'python',
          request = 'attach',
          name = 'Attach to process by PID',
          processId = require('dap.utils').pick_process,
          justMyCode = false,
        },
      }
    end,
  },
  {
    'nvim-neotest/neotest',
    dependencies = {
      'nvim-neotest/nvim-nio',
      'nvim-lua/plenary.nvim',
      'antoinemadec/FixCursorHold.nvim',
      'nvim-treesitter/nvim-treesitter',
      {
        'nvim-neotest/neotest-python',
      },
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
        status = { virtual_text = false },
        output = { open_on_run = true },
        -- quickfix = {
        --   open = function()
        --     if package.loaded.trouble then
        --       require('trouble').open { mode = 'quickfix', focus = false }
        --     else
        --       vim.cmd 'copen'
        --     end
        --   end,
        -- },
        icons = {
          failed = '✗',
          passed = '✔',
          pending = '⧗',
          error = '!',
          running = '↯',
          unknown = '?',
        },
      }
    end,
    init = function()
      -- Document key chains
      require('which-key').add {
        { '<leader>t', group = 'Unit test' },
      }
    end,
    -- stylua: ignore
    keys = {
      { "<leader>tt", function() require("neotest").run.run(vim.fn.expand("%")) end, desc = "Neotest: run file" },
      { "<leader>tT", function() require("neotest").run.run(vim.uv.cwd()) end, desc = "Neotest: run all test files" },
      { "<leader>tr", function() require("neotest").run.run() end, desc = "Neotest: run nearest" },
      { "<leader>tl", function() require("neotest").run.run_last() end, desc = "Neotest: run last" },
      { "<leader>ts", function() require("neotest").summary.toggle() end, desc = "Neotest: [t]oggle [s]ummary" },
      { "<leader>to", function() require("neotest").output.open({ enter = true, auto_close = true }) end, desc = "Neotest: [t]oggle [o]utput" },
      { "<leader>tO", function() require("neotest").output_panel.toggle() end, desc = "Neotest: [t]oggle [O]utput panel" },
      { "<leader>tS", function() require("neotest").run.stop() end, desc = "Neotest: [S]top" },
    },
  },
  {
    'lucaSartore/nvim-dap-exception-breakpoints',
    dependencies = { 'mfussenegger/nvim-dap' },

    config = function()
      local set_exception_breakpoints = require 'nvim-dap-exception-breakpoints'

      vim.api.nvim_set_keymap(
        'n',
        '<leader>dy',
        '',
        { desc = 'Set condition breakpoints', callback = set_exception_breakpoints }
      )
    end,
  },
}
