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
    -- stylua: ignore
    keys = {
      { '<CR>', ':QuartoSend<CR>', desc = 'Quarto: run cell', },
      { '<localleader>jc', ':QuartoActivate<CR>', desc = 'Quarto: activate', },
      { '<localleader>ja', function() require('quarto.runner').run_above() end, desc = 'Quarto: run cell and all above', },
      { '<localleader>jb', function() require('quarto.runner').run_below() end, desc = 'Quarto: run cell and all below', },
      { '<localleader>jA', function() require('quarto.runner').run_all() end, desc = 'Quarto: run all cells', },
      { '<localleader>jl', function() require('quarto.runner').run_line() end, desc = 'Quarto: run line', },
      { '<localleader>jp', ':QuartoPreview<CR>', desc = 'Quarto: open preview', },
      { '<localleader>jP', ':QuartoClosePreview<CR>', desc = 'Quarto: close preview', },
      -- { '<localleader>jj', "ko\rpyc<cmd>lua require('luasnip').expand()<CR>", desc = 'Snippet: new cell', },
      { '<localleader>j/', 'O```\r\r```{python}<ESC>/```<ESC><cmd>nohlsearch<CR>O', desc = 'Split cell', },
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
        { '<leader>j', group = 'Jupyter', icon = { icon = '', color = 'blue' } },
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

      -- Clear the MoltenCell highlight
      vim.api.nvim_command 'highlight clear MoltenCell'
    end,
    keys = {
      {
        '<localleader>je',
        ':noautocmd MoltenEnterOutput<CR>:noautocmd MoltenEnterOutput<CR>[ow',
        desc = 'Molten: enter output',
      },
      { '<localleader>jr', ':MoltenRestart<cr>', desc = 'Molten: restart' },
      { '<localleader>ji', ':MoltenInterrupt<cr>', desc = 'Molten: interrupt' },
      {
        '<localleader>jo',
        ':MoltenImagePopup<cr>',
        desc = 'Molten: open image',
        silent = true,
      },
      --   {
      --     '<localleader>jv',
      --     ':<C-u>MoltenEvaluateVisual<cr>',
      --     mode = 'v',
      --     desc = 'Jupyter: eval visual',
      --     silent = true,
      --   },
      --   {
      --     '<localleader>jl',
      --     ':MoltenEvaluateLine<cr>',
      --     desc = 'Jupyter: eval line',
      --     silent = true,
      --   },
      --   {
      --     '<localleader>jr',
      --     ':MoltenReevaluateCell<cr>',
      --     desc = 'Jupyter: re-eval cell',
      --     silent = true,
      --   },
      --   {
      --     '<localleader>jv',
      --     ':MoltenEvaluateVisual<cr>',
      --     desc = 'Jupyter: eval visual',
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
        desc = 'Set up repl keymap',
        callback = function()
          -- bufmap(0, 'n', '<localleader>js', '<Plug>(REPLStart-ipython)', {
          --   desc = 'Yarepl: start a repl',
          -- })
          -- bufmap(0, 'n', '<localleader>rf', '<Plug>(REPLFocus)', {
          --   desc = 'Yarepl: focus on repl',
          -- })
          -- bufmap(0, 'n', '<localleader>jv', '<CMD>Telescope REPLShow<CR>', {
          --   desc = 'Yarepl: view REPLs in Telescope',
          -- })
          -- bufmap(0, 'n', '<localleader>rh', '<Plug>(REPLHide)', {
          --   desc = 'Hide repl',
          -- })
          bufmap(0, 'n', '<localleader>k', '<Plug>(REPLSendOperator)vic', {
            desc = 'Yarepl: send cell to repl',
          })
          bufmap(0, 'v', '<localleader>jv', '<Plug>(REPLSendVisual-ipython)', {
            desc = 'Yarepl: send visual to repl',
          })
          -- bufmap(0, 'n', '<localleader>s', '<Plug>(REPLSendOperator)', {
          --   desc = 'Send current line to REPL',
          -- })
          -- bufmap(0, 'n', '<localleader>re', '<Plug>(REPLExec)', {
          --   desc = 'Execute command in repl',
          --   expr = true,
          -- })
          bufmap(0, 'n', '<localleader>jq', '<Plug>(REPLClose)', {
            desc = 'Yarepl: quit repl',
          })
          bufmap(0, 'n', '<localleader>ju', '<CMD>REPLCleanup<CR>', {
            desc = 'Yarepl: clean up repls',
          })
          -- bufmap(0, 'n', '<localleader>rS', '<CMD>REPLSwap<CR>', {
          --   desc = 'Swap repls.',
          -- })
          -- bufmap(0, 'n', '<localleader>r?', '<Plug>(REPLStart)', {
          --   desc = 'Start an repl from available repl metas',
          -- })
          bufmap(0, 'n', '<localleader>jt', '<CMD>REPLAttachBufferToREPL<CR>', {
            desc = 'Yarepl: attach current buffer to a repl',
          })
          -- bufmap(0, 'n', '<localleader>rd', '<CMD>REPLDetachBufferToREPL<CR>', {
          --   desc = 'Detach current buffer to any repl',
          -- })
        end,
      })
    end,
  },
  {
    'Vigemus/iron.nvim',
    enabled = false,
    config = function()
      require('iron.core').setup {
        config = {
          scratch_repl = true,
          repl_open_cmd = 'vertical botright 80 split',
          -- repl_open_cmd = 'ToggleTerm',
          repl_definition = {
            python = {
              command = function(meta)
                local container_name = os.getenv 'DBX_CONTAINER_NAME' or 'grubhub-dev'
                -- Check if ipython is available in the distrobox
                local handle = io.popen(
                  'distrobox enter ' .. container_name .. ' -- which ipython 2>/dev/null'
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
                      .. container_name
                      .. ' -- uv pip install ipykernel'

                    -- Use the waiting terminal
                    wait_for_terminal(cmd)
                  end
                end
                -- Return ipython command if available
                return {
                  'distrobox',
                  'enter',
                  container_name,
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
    'hdemers/vim-dadbod-ui',
    branch = 'bind-parameters-without-quotes',
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
        desc = 'DBUI: open dbui in a new tab',
      },
    },
    init = function()
      -- Your DBUI configuration
      vim.g.db_ui_use_nerd_fonts = 1
      vim.g.db_ui_bind_param_pattern = '{{\\w\\+}}'
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
  {
    -- 'hdemers/nvim-dbee',
    dir = '/home/hdemers/Projets/nvim-dbee/',
    enabled = false,
    dependencies = {
      'MunifTanjim/nui.nvim',
    },
    build = function()
      -- Install tries to automatically detect the install method.
      -- if it fails, try calling it with one of these parameters:
      --    "curl", "wget", "bitsadmin", "go"
      require('dbee').install()
    end,
    config = function()
      require('dbee').setup {
        sources = {
          require('dbee.sources').EnvSource:new 'DBEE_CONNECTIONS',
        },
      }
    end,
  },
}
