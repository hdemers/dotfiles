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
    },
    ft = { 'quarto' },
    dev = false,
    opts = {
      lspFeatures = {
        languages = {
          'r',
          'python',
          'julia',
          'bash',
          'lua',
          'html',
          'dot',
          'javascript',
          'typescript',
          'ojs',
        },
      },
      codeRunner = {
        enabled = true,
        default_method = 'molten',
      },
    },
    keys = {
      {
        '<localleader>jc',
        ':QuartoActivate<CR>',
        desc = 'Quarto: a[c]tivate',
      },
    },
    init = function()
      local runner = require 'quarto.runner'
      vim.keymap.set(
        'n',
        '<localleader><CR>',
        ':QuartoSend<CR>',
        { desc = 'Quarto: run cell', silent = true }
      )
      vim.keymap.set(
        'n',
        '<localleader>ja',
        runner.run_above,
        { desc = 'Quarto: run cell and all [a]bove', silent = true }
      )
      vim.keymap.set(
        'n',
        '<localleader>jb',
        runner.run_below,
        { desc = 'Quarto: run cell and all [b]elow', silent = true }
      )
      vim.keymap.set(
        'n',
        '<localleader>jA',
        runner.run_all,
        { desc = 'Quarto: run [A]ll cells', silent = true }
      )
      vim.keymap.set(
        'n',
        '<localleader>jl',
        runner.run_line,
        { desc = 'Quarto: run [l]ine', silent = true }
      )
      vim.keymap.set(
        'v',
        '<localleader>jv',
        runner.run_range,
        { desc = 'Quarto: run [v]isual range', silent = true }
      )
      vim.keymap.set(
        'n',
        '<localleader>jp',
        ':QuartoPreview<CR>',
        { desc = 'Quarto: open [p]review', silent = true }
      )
      vim.keymap.set(
        'n',
        '<localleader>jP',
        ':QuartoClosePreview<CR>',
        { desc = 'Quarto: close [p]review', silent = true }
      )
      vim.keymap.set(
        'n',
        '<localleader>jj',
        "o\rpyc<cmd>lua require('luasnip').expand()<CR>",
        { desc = 'Snippet: [n]ew cell', noremap = true }
      )
      vim.keymap.set(
        'n',
        '<localleader>j/',
        'O```\r\r```{python}<ESC>/```<ESC><cmd>nohlsearch<CR>O',
        { desc = 'split cell', noremap = true }
      )

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
      -- require('which-key').register {
      --   ['<localleader>j'] = { name = '[J]upyter', _ = 'which_key_ignore' },
      -- }
    end,
    keys = {
      {
        '<localleader>je',
        ':noautocmd MoltenEnterOutput<CR>',
        desc = 'Molten: [e]nter output',
      },
      { '<localleader>jr', ':MoltenRestart<cr>', desc = 'Molten: [r]estart' },
      { '<localleader>ji', ':MoltenInterrupt<cr>', desc = 'Molten: [i]nterrupt' },
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
    'lukas-reineke/headlines.nvim',
    dependencies = 'nvim-treesitter/nvim-treesitter',
    config = function()
      require('headlines').setup {
        quarto = {
          query = vim.treesitter.query.parse(
            'markdown',
            [[
                (fenced_code_block) @codeblock
            ]]
          ),
          codeblock_highlight = 'CodeBlock',
          treesitter_language = 'markdown',
        },
        markdown = {
          bullets = {},
        },
      }
    end,
  },
  {
    'milanglacier/yarepl.nvim',
    event = 'VeryLazy',
    config = true,
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
          bufmap(0, 'n', '<localleader>js', '<Plug>(REPLStart)', {
            desc = 'yarepl: [s]tart a repl',
          })
          -- bufmap(0, 'n', '<localleader>rf', '<Plug>(REPLFocus)', {
          --   desc = 'yarepl: [f]ocus on REPL',
          -- })
          bufmap(0, 'n', '<localleader>jv', '<CMD>Telescope REPLShow<CR>', {
            desc = 'yarepl: [v]iew REPLs in Telescope',
          })
          -- bufmap(0, 'n', '<localleader>rh', '<Plug>(REPLHide)', {
          --   desc = 'Hide REPL',
          -- })
          bufmap(0, 'n', '<localleader>k', '<Plug>(REPLSendOperator)', {
            desc = 'yarepl: send cell to repl',
          })
          -- bufmap(0, 'n', '<localleader>ss', '<Plug>(REPLSendLine)', {
          --   desc = 'Send line to REPL',
          -- })
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
    opts = {
      config = {
        scratch_repl = true,
        repl_open_cmd = 'vertical botright 80 split',
        repl_definition = {
          quarto = { command = 'ipython' },
        },
      },
      keymaps = {
        -- send_mark = '<localleader>k',
      },
    },
    config = function(_, opts)
      require('iron.core').setup(opts)
    end,
  },
}
