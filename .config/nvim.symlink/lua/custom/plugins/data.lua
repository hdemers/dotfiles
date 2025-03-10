return {
  {
    'quarto-dev/quarto-vim',
    dependencies = 'vim-pandoc/vim-pandoc-syntax',
    ft = { 'quarto' },
  },
  {
    'quarto-dev/quarto-nvim',
    dependencies = {
      'jmbuhr/otter.nvim',
      'nvim-treesitter/nvim-treesitter',
      'akinsho/toggleterm.nvim',
    },
    ft = { 'quarto' },
    dev = false,
    opts = {
      -- lspFeatures = {
      --   languages = {
      --     'r',
      --     'python',
      --     'julia',
      --     'bash',
      --     'lua',
      --     'html',
      --     'dot',
      --     'javascript',
      --     'typescript',
      --     'ojs',
      --   },
      -- },
    },
    keys = {
      {
        '<CR>',
        ':QuartoSend<CR>',
        desc = 'Quarto: run cell',
      },
      {
        '<localleader>jc',
        ':QuartoActivate<CR>',
        desc = 'Quarto: a[c]tivate',
      },
      {
        '<localleader>ja',
        function()
          require('quarto.runner').run_above()
        end,
        desc = 'Quarto: run cell and all [a]bove',
      },
      {
        '<localleader>jb',
        function()
          require('quarto.runner').run_below()
        end,
        desc = 'Quarto: run cell and all [b]elow',
      },
      {
        '<localleader>jA',
        function()
          require('quarto.runner').run_all()
        end,
        desc = 'Quarto: run [A]ll cells',
      },
      {
        '<localleader>jl',
        function()
          require('quarto.runner').run_line()
        end,
        desc = 'Quarto: run [l]ine',
      },
      {
        '<localleader>jp',
        ':QuartoPreview<CR>',
        desc = 'Quarto: open [p]review',
      },
      {
        '<localleader>jP',
        ':QuartoClosePreview<CR>',
        desc = 'Quarto: close [p]review',
      },
      {
        '<localleader>jj',
        "ko\rpyc<cmd>lua require('luasnip').expand()<CR>",
        desc = 'Snippet: [n]ew cell',
      },
      {
        '<localleader>j/',
        'O```\r\r```{python}<ESC>/```<ESC><cmd>nohlsearch<CR>O',
        desc = 'split cell',
      },
    },
    config = function(_, opts)
      local quarto = require 'quarto'
      local misc = require 'misc'

      local function runner(cell, _)
        misc.start_ipython()
        vim.wait(6000, function()
          return misc.ipython_term ~= nil
        end, 100)
        if misc.ipython_term == nil then
          vim.notify('Failed to start ipython.', vim.log.levels.ERROR)
          return
        end

        local filtered_lines = vim.tbl_filter(function(line)
          -- Return false for empty lines or lines starting with # (including those with leading whitespace)
          return line:match '^%s*$' == nil and line:match '^%s*#' == nil
        end, cell.text)

        local text_lines = table.concat(filtered_lines, '\n')
        -- Send this as bracketed content
        text_lines = '\x1b[200~' .. text_lines .. '\x1b[201~'
        misc.ipython_term:send(text_lines, true)
      end

      -- Update opts to add runner.
      opts.codeRunner = {
        enabled = true,
        default_method = runner,
      }
      quarto.setup(opts)
    end,
    init = function()
      local runner = require 'quarto.runner'

      -- local ts_utils = require 'nvim-treesitter.ts_utils'

      -- local function is_cursor_in_class_inner()
      --   local node = ts_utils.get_node_at_cursor()
      --   while node do
      --     print(node)
      --     local node_type = node:type()
      --     print(node_type)
      --     if node_type == 'fenced_code_block' then
      --       print 'found it'
      --       return true
      --     end
      --     node = ts_utils.get_previous_node(node, true, true)
      --   end
      --   return false
      -- end
      --
      -- local function add_new_cell()
      --   if is_cursor_in_class_inner() then
      --     print 'in cell'
      --     vim.api.nvim_feedkeys('][', 'n', false)
      --     vim.api.nvim_feedkeys('o', 'n', false)
      --   else
      --     print 'not in cell'
      --     vim.api.nvim_feedkeys(
      --       "o\rpyc<cmd>lua require('luasnip').expand()<CR>",
      --       'n',
      --       false
      --     )
      --   end
      -- end

      -- vim.keymap.set(
      --   'v',
      --   '<localleader>jv',
      --   runner.run_range,
      --   { desc = 'Quarto: run [v]isual range', silent = true }
      -- )
      -- Document key chains
      require('which-key').add {
        { '<leader>j', group = '[J]upyter' },
      }
    end,
  },

  { -- directly open ipynb files as quarto documents
    -- and convert back behind the scenes
    'GCBallesteros/jupytext.nvim',
    opts = {
      custom_language_formatting = {
        python = {
          extension = 'qmd',
          style = 'quarto',
          force_ft = 'quarto',
        },
        r = {
          extension = 'qmd',
          style = 'quarto',
          force_ft = 'quarto',
        },
      },
    },
  },
  {
    'jmbuhr/otter.nvim',
    dev = false,
    dependencies = {
      {
        'neovim/nvim-lspconfig',
        'nvim-treesitter/nvim-treesitter',
        'hrsh7th/nvim-cmp',
      },
    },
    opts = {
      lsp = {
        hover = {
          border = 'none',
        },
      },
      buffers = {
        set_filetype = true,
        write_to_disk = false,
      },
      handle_leading_whitespace = true,
    },
  },
  {
    'benlubas/molten-nvim',
    lazy = false,
    cmd = { 'MoltenInit' },
    build = ':UpdateRemotePlugins',
    init = function()
      -- vim.g.molten_cover_emtpy_lines = true
      vim.g.molten_virt_text_output = true
      -- vim.g.molten_image_provider = 'image.nvim'
      -- vim.g.molten_output_win_max_height = 20
      vim.g.molten_virt_lines_off_by_1 = true
      vim.g.molten_auto_open_output = false
      vim.g.molten_virt_text_max_lines = 20
      vim.g.molten_auto_image_popup = true
      -- require('which-key').register {
      --   ['<localleader>j'] = { name = '[J]upyter', _ = 'which_key_ignore' },
      -- }

      -- Clear the MoltenCell highlight
      vim.api.nvim_command 'highlight clear MoltenCell'
    end,
    keys = {
      {
        '<localleader>je',
        ':noautocmd MoltenEnterOutput<CR>:noautocmd MoltenEnterOutput<CR>[ow',
        desc = 'Molten: [e]nter output',
      },
      { '<localleader>jr', ':MoltenRestart<cr>', desc = 'Molten: [r]estart' },
      { '<localleader>ji', ':MoltenInterrupt<cr>', desc = 'Molten: [i]nterrupt' },
      {
        '<localleader>jo',
        ':MoltenImagePopup<cr>',
        desc = 'Molten: [o]pen image',
        silent = true,
      },
      --   {
      --     '<localleader>jv',
      --     ':<C-u>MoltenEvaluateVisual<cr>',
      --     mode = 'v',
      --     desc = 'Jupyter: eval [v]isual',
      --     silent = true,
      --   },
      --   {
      --     '<localleader>jl',
      --     ':MoltenEvaluateLine<cr>',
      --     desc = 'Jupyter: eval [l]ine',
      --     silent = true,
      --   },
      --   {
      --     '<localleader>jr',
      --     ':MoltenReevaluateCell<cr>',
      --     desc = 'Jupyter: [r]e-eval cell',
      --     silent = true,
      --   },
      --   {
      --     '<localleader>jv',
      --     ':MoltenEvaluateVisual<cr>',
      --     desc = 'Jupyter: eval [v]isual',
      --     silent = true,
      --     mode = 'v',
      --   },
    },
  },
  {
    'milanglacier/yarepl.nvim',
    event = 'VeryLazy',
    enabled = false,
    config = function()
      local yarepl = require 'yarepl'
      yarepl.setup {
        wincmd = 'botright 100vsplit',
      }
    end,
    init = function()
      local autocmd = vim.api.nvim_create_autocmd
      local bufmap = vim.api.nvim_buf_set_keymap

      autocmd('FileType', {
        pattern = {
          'quarto',
          'markdown',
          'markdown.pandoc',
          'rmd',
          'python',
          'sh',
          'REPL',
          'r',
        },
        group = vim.api.nvim_create_augroup('yarepl', {}),
        desc = 'set up REPL keymap',
        callback = function()
          -- bufmap(0, 'n', '<localleader>js', '<Plug>(REPLStart-ipython)', {
          --   desc = 'yarepl: [s]tart a repl',
          -- })
          -- bufmap(0, 'n', '<localleader>rf', '<Plug>(REPLFocus)', {
          --   desc = 'yarepl: [f]ocus on REPL',
          -- })
          -- bufmap(0, 'n', '<localleader>jv', '<CMD>Telescope REPLShow<CR>', {
          --   desc = 'yarepl: [v]iew REPLs in Telescope',
          -- })
          -- bufmap(0, 'n', '<localleader>rh', '<Plug>(REPLHide)', {
          --   desc = 'Hide REPL',
          -- })
          bufmap(0, 'n', '<localleader>k', '<Plug>(REPLSendOperator)vic', {
            desc = 'yarepl: send cell to repl',
          })
          bufmap(0, 'v', '<localleader>jv', '<Plug>(REPLSendVisual-ipython)', {
            desc = 'yarepl: send [v]isual to REPL',
          })
          -- bufmap(0, 'n', '<localleader>s', '<Plug>(REPLSendOperator)', {
          --   desc = 'Send current line to REPL',
          -- })
          -- bufmap(0, 'n', '<localleader>re', '<Plug>(REPLExec)', {
          --   desc = 'Execute command in REPL',
          --   expr = true,
          -- })
          bufmap(0, 'n', '<localleader>jq', '<Plug>(REPLClose)', {
            desc = 'yarepl: [q]uit REPL',
          })
          bufmap(0, 'n', '<localleader>ju', '<CMD>REPLCleanup<CR>', {
            desc = 'yarepl: clean [u]p REPLs',
          })
          -- bufmap(0, 'n', '<localleader>rS', '<CMD>REPLSwap<CR>', {
          --   desc = 'Swap REPLs.',
          -- })
          -- bufmap(0, 'n', '<localleader>r?', '<Plug>(REPLStart)', {
          --   desc = 'Start an REPL from available REPL metas',
          -- })
          bufmap(0, 'n', '<localleader>jt', '<CMD>REPLAttachBufferToREPL<CR>', {
            desc = 'yarepl: a[t]tach current buffer to a REPL',
          })
          -- bufmap(0, 'n', '<localleader>rd', '<CMD>REPLDetachBufferToREPL<CR>', {
          --   desc = 'Detach current buffer to any REPL',
          -- })
        end,
      })
    end,
  },
  {
    'Vigemus/iron.nvim',
    enabled = true,
    config = function()
      require('iron.core').setup {
        config = {
          scratch_repl = true,
          repl_open_cmd = 'vertical botright 80 split',
          -- repl_open_cmd = 'ToggleTerm',
          repl_definition = {
            python = {
              command = function(meta)
                local distrobox_name = os.getenv 'DISTROBOX_NAME' or 'grubhub-dev'
                -- Check if ipython is available in the distrobox
                local handle = io.popen(
                  'distrobox enter ' .. distrobox_name .. ' -- which ipython 2>/dev/null'
                )
                if not handle then
                  vim.notify('Failed to check for ipython.', vim.log.levels.ERROR)
                  return nil
                end
                local result = handle:read '*a'
                handle:close()
                if result == '' then
                  -- Prompt user to install ipykernel
                  vim.notify(
                    'ipython is not available. Asking for input.',
                    vim.log.levels.ERROR
                  )
                  local input = vim.fn
                    .input('Confirm', 'ipython not found. Install ipykernel? [y/N]: ')
                    :sub(-1)

                  vim.notify('input: ' .. input)
                  if input and input:lower() == 'y' then
                    local Terminal = require('toggleterm.terminal').Terminal
                    -- Create a function that returns a promise-like object
                    local function wait_for_terminal(cmd)
                      local done = false

                      local term = Terminal:new {
                        direction = 'float',
                        cmd = cmd,
                        hidden = false,
                        float_opts = { width = 100, height = 40 },
                        on_exit = function()
                          done = true
                        end,
                      }

                      term:open()

                      -- Wait for the terminal to finish
                      vim.wait(30000, function()
                        return done
                      end, 100)

                      -- Give a small delay for cleanup
                      vim.defer_fn(function()
                        term:close()
                      end, 5000)
                    end

                    local cmd = 'distrobox enter '
                      .. distrobox_name
                      .. ' -- uv pip install ipykernel'

                    -- Use the waiting terminal
                    wait_for_terminal(cmd)
                  end
                end
                -- Return ipython command if available
                return {
                  'distrobox',
                  'enter',
                  distrobox_name,
                  '--',
                  'ipython',
                  '--no-autoindent',
                }
              end,
            },
            quarto = {
              command = {
                'distrobox',
                'enter',
                'grubhub-dev',
                '--',
                'ipython',
                '--no-autoindent',
              },
            },
          },
        },
      }
    end,
  },
  {
    'chrisbra/csv.vim',
  },
  {
    'kristijanhusak/vim-dadbod-ui',
    dependencies = {
      -- { 'tpope/vim-dadbod', lazy = true },
      { 'hdemers/vim-dadbod', branch = 'add-presto-password', lazy = true },
      {
        'kristijanhusak/vim-dadbod-completion',
        ft = { 'sql', 'mysql', 'plsql' },
        lazy = true,
      }, -- Optional
    },
    cmd = {
      'DBUI',
      'DBUIToggle',
      'DBUIAddConnection',
      'DBUIFindBuffer',
    },
    keys = {
      {
        '<leader>cq',
        ':tabnew DBUI<CR>:DBUI<CR>',
        desc = 'DBUI: Open DBUI in a new tab',
      },
    },
    init = function()
      -- Your DBUI configuration
      vim.g.db_ui_use_nerd_fonts = 1
    end,
    config = function()
      -- Add cmp-nvim source for db completion
      require('cmp').setup.buffer {
        sources = {
          { name = 'vim-dadbod-completion' },
        },
      }
    end,
  },
}
