return {
  {
    -- Main LSP Configuration
    'neovim/nvim-lspconfig',
    dependencies = {
      -- Automatically install LSPs and related tools to stdpath for Neovim
      { 'mason-org/mason.nvim', opts = {} },
      'mason-org/mason-lspconfig.nvim',
      'WhoIsSethDaniel/mason-tool-installer.nvim',

      -- Useful status updates for LSP.
      { 'j-hui/fidget.nvim', opts = {} },

      -- Allows extra capabilities provided by blink.cmp
      'saghen/blink.cmp',
      'folke/neoconf.nvim',
    },
    config = function()
      --  This function gets run when an LSP attaches to a particular buffer.
      --    That is to say, every time a new file is opened that is associated with
      --    an lsp (for example, opening `main.rs` is associated with `rust_analyzer`) this
      --    function will be executed to configure the current buffer
      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
        callback = function(event)
          -- NOTE: Remember that Lua is a real programming language, and as such it is possible
          -- to define small helper and utility functions so you don't have to repeat yourself.
          --
          -- In this case, we create a function that lets us more easily define mappings specific
          -- for LSP related items. It sets the mode, buffer and description for us each time.
          local map = function(keys, func, desc, mode)
            mode = mode or 'n'
            vim.keymap.set(
              mode,
              keys,
              func,
              { buffer = event.buf, desc = 'LSP: ' .. desc }
            )
          end

          -- Opens a popup that displays documentation about the word under your cursor
          --  See `:help K` for why this keymap
          map('K', vim.lsp.buf.hover, 'Hover Documentation')

          -- The following two autocommands are used to highlight references of the
          -- word under your cursor when your cursor rests there for a little while.
          --    See `:help CursorHold` for information about when this is executed
          --
          -- When you move your cursor, the highlights will be cleared (the second autocommand).
          local client = vim.lsp.get_client_by_id(event.data.client_id)
          if
            client
            and client:supports_method(
              vim.lsp.protocol.Methods.textDocument_documentHighlight,
              event.buf
            )
          then
            local highlight_augroup =
              vim.api.nvim_create_augroup('kickstart-lsp-highlight', { clear = false })
            vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.document_highlight,
            })

            vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.clear_references,
            })

            vim.api.nvim_create_autocmd('LspDetach', {
              group = vim.api.nvim_create_augroup(
                'kickstart-lsp-detach',
                { clear = true }
              ),
              callback = function(event2)
                vim.lsp.buf.clear_references()
                vim.api.nvim_clear_autocmds {
                  group = 'kickstart-lsp-highlight',
                  buffer = event2.buf,
                }
              end,
            })
          end
        end,
      })

      -- Diagnostic Config
      -- See :help vim.diagnostic.Opts
      vim.diagnostic.config {
        severity_sort = true,
        float = { border = 'rounded', source = 'if_many' },
        underline = { severity = vim.diagnostic.severity.ERROR },
        signs = vim.g.have_nerd_font
            and {
              text = {
                -- [vim.diagnostic.severity.ERROR] = '■ ',
                -- [vim.diagnostic.severity.WARN] = '▲ ',
                -- [vim.diagnostic.severity.INFO] = 'ℹ ',
                -- [vim.diagnostic.severity.HINT] = '󰌶 ',
                [vim.diagnostic.severity.ERROR] = '󰅚 ',
                [vim.diagnostic.severity.WARN] = '󰀪 ',
                [vim.diagnostic.severity.INFO] = '󰋽 ',
                [vim.diagnostic.severity.HINT] = '󰌶 ',
              },
            }
          or {},
        virtual_text = {
          source = 'if_many',
          spacing = 2,
          format = function(diagnostic)
            local diagnostic_message = {
              [vim.diagnostic.severity.ERROR] = diagnostic.message,
              [vim.diagnostic.severity.WARN] = diagnostic.message,
              [vim.diagnostic.severity.INFO] = diagnostic.message,
              [vim.diagnostic.severity.HINT] = diagnostic.message,
            }
            return diagnostic_message[diagnostic.severity]
          end,
        },
      }

      -- LSP servers and clients are able to communicate to each other what features they support.
      --  By default, Neovim doesn't support everything that is in the LSP specification.
      --  When you add blink.cmp, luasnip, etc. Neovim now has *more* capabilities.
      --  So, we create new capabilities with blink.cmp, and then broadcast that to the servers.
      local capabilities = require('blink.cmp').get_lsp_capabilities()

      -- Enable the following language servers
      --  Feel free to add/remove any LSPs that you want here. They will automatically be installed.
      --
      --  Add any additional override configuration in the following tables. Available keys are:
      --  - cmd (table): Override the default command used to start the server
      --  - filetypes (table): Override the default list of associated filetypes for the server
      --  - capabilities (table): Override fields in capabilities. Can be used to disable certain LSP features.
      --  - settings (table): Override the default settings passed when initializing the server.
      --        For example, to see the options for `lua_ls`, you could go to: https://luals.github.io/wiki/settings/
      local servers = {
        ruff = {
          on_attach = function(client)
            if client.name == 'ruff' then
              -- Disable hover in favor of Pyright
              client.server_capabilities.hoverProvider = false
            end
          end,
        },
        ty = {
          cmd = { 'ty', 'server' },
          filetypes = { 'python' },
          root_markers = { 'ty.toml', 'pyproject.toml', '.git' },
        },
        basedpyright = {
          enable = false,
          settings = {
            basedpyright = {
              -- Using Ruff's import organizer
              disableOrganizeImports = true,
              analysis = {
                diagnosticMode = 'openFilesOnly',
                inlayHints = {
                  callArguments = true,
                },
              },
            },
            -- python = {
            --   analysis = {
            --     -- Ignore all files for analysis to exclusively use Ruff for linting
            --     -- ignore = { '*' },
            --     diagnosticMode = 'workspace',
            --   },
            -- },
          },
        },
        -- beancount = {},
        arduino_language_server = {
          cmd = {
            'arduino-language-server',
            '-clangd',
            '~/.local/share/nvim/mason/bin/clangd',
          },
        },
        clangd = {},
        jdtls = {}, -- Add Java language server
        jsonls = {},
        lua_ls = {
          settings = {
            Lua = {
              completion = {
                callSnippet = 'Replace',
              },
              -- You can toggle below to ignore Lua_LS's noisy `missing-fields` warnings
              diagnostics = { disable = { 'missing-fields' } },
            },
          },
        },
      }

      local neoconf = require 'neoconf'
      neoconf.setup()

      local ensure_installed = vim.tbl_keys(servers or {})
      vim.list_extend(ensure_installed, {
        'stylua', -- Used to format Lua code
      })
      require('mason-tool-installer').setup { ensure_installed = ensure_installed }

      -- Installed LSPs are configured and enabled automatically with mason-lspconfig
      -- The loop below is for overriding the default configuration of LSPs with the ones in the servers table
      for server_name, config in pairs(servers) do
        -- Override the default configuration with the one found in .neoconf.json, if it exists.
        if neoconf.get('lspconfig.' .. server_name) then
          config = neoconf.get('lspconfig.' .. server_name)
          vim.lsp.config(server_name, config)
        else
          vim.lsp.config(server_name, config)
        end
        -- Enable all servers, unless `enable` is explicitly set, in which case we enable only if `true`.
        if config.enable ~= false then
          vim.lsp.enable(server_name)
        end
      end
    end,
  },
  {
    'folke/trouble.nvim',
    -- branch = 'dev',
    cmd = 'Trouble',
    -- stylua: ignore
    keys = {
      { '<leader>cx', '<cmd>Trouble diagnostics toggle<cr>', desc = 'Trouble: toggle all diagnostics', },
      { '<leader>cX', '<cmd>Trouble diagnostics toggle filter.buf=0<cr>', desc = 'Trouble: toggle buffer diagnostics', },
      { '<leader>cs', '<cmd>Trouble symbols toggle focus=false win.size.width=70<cr>', desc = 'Trouble: show symbols', },
      { '<leader>cd', '<cmd>Trouble lsp toggle focus=false win.position=right win.size.width=70<cr>', desc = 'Trouble: lsp definitions/references/etc.', },
      { '<leader>cL', '<cmd>Trouble loclist toggle<cr>', desc = 'Trouble: toggle location list', },
      { '<leader>cQ', '<cmd>Trouble qflist toggle<cr>', desc = 'Trouble: toggle quickfix list', },
      {
        '[t',
        function()
          if require('trouble').is_open() then
            require('trouble').prev { skip_groups = true, jump = true }
          else
            local ok, err = pcall(vim.cmd.cprev)
            if not ok then
              vim.notify(err, vim.log.levels.ERROR)
            end
          end
        end,
        desc = 'Previous trouble/quickfix item',
      },
      {
        ']t',
        function()
          if require('trouble').is_open() then
            require('trouble').next { skip_groups = true, jump = true }
          else
            local ok, err = pcall(vim.cmd.cprev)
            if not ok then
              vim.notify(err, vim.log.levels.ERROR)
            end
          end
        end,
        desc = 'Next trouble/quickfix item',
      },
    },
    opts = {
      modes = {
        diagnostics = {
          mode = 'diagnostics',
          preview = {
            type = 'split',
            relative = 'win',
            position = 'right',
            size = 0.5,
          },
        },
      },
    },
  },
  -- I wish lspconfig had sqlfluff support, but it doesn't. And nvim-lint doesn't
  -- appear to support code-actions. So, I'm resorting to use `null-ls` for now.
  {
    'jay-babu/mason-null-ls.nvim',
    event = { 'BufReadPre', 'BufNewFile' },
    dependencies = {
      'mason-org/mason.nvim',
      { 'nvimtools/none-ls.nvim', dependencies = 'nvim-lua/plenary.nvim' },
    },
    config = function()
      require('mason').setup()
      local null_ls = require 'null-ls'
      local sources = {
        null_ls.builtins.formatting.sqlfluff.with {
          extra_args = { '--dialect', 'trino' }, -- change to your dialect
        },
        null_ls.builtins.diagnostics.bean_check,
        null_ls.builtins.formatting.bean_format,
        -- null_ls.builtins.diagnostics.mypy.with(mypy_opts),
      }

      null_ls.setup { sources = sources, debug = true }

      require('mason-null-ls').setup {
        ensure_installed = {},
        automatic_installation = true,
      }
    end,
  },
  {
    'folke/lazydev.nvim',
    ft = 'lua', -- only load on lua files
    opts = {
      library = {
        -- See the configuration section for more details
        -- Load luvit types when the `vim.uv` word is found
        { path = 'luvit-meta/library', words = { 'vim%.uv' } },
      },
    },
  },
  { 'Bilal2453/luvit-meta', lazy = true }, -- optional `vim.uv` typings
}
