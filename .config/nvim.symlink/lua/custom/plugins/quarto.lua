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
        ':QuartoSend<CR>]]',
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
      require('which-key').register {
        ['<leader>j'] = { name = '[J]upyter', _ = 'which_key_ignore' },
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
  { -- preview equations
    'jbyuki/nabla.nvim',
    keys = {
      {
        '<leader>jm',
        ':lua require"nabla".toggle_virt()<cr>',
        desc = 'Nabla: toggle [m]ath equations',
      },
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
      }
    end,
  },
  { -- send code from python/r/qmd documets to a terminal or REPL
    -- like ipython, R, bash
    'jpalardy/vim-slime',
    dev = false,
    init = function()
      vim.b['quarto_is_python_chunk'] = false
      Quarto_is_in_python_chunk = function()
        require('otter.tools.functions').is_otter_language_context 'python'
      end

      vim.cmd [[
      let g:slime_dispatch_ipython_pause = 100
      function SlimeOverride_EscapeText_quarto(text)
        call v:lua.Quarto_is_in_python_chunk()
        if exists('g:slime_python_ipython') && len(split(a:text,"\n")) > 1 && b:quarto_is_python_chunk && !(exists('b:quarto_is_r_mode') && b:quarto_is_r_mode)
          return ["%cpaste -q\n", g:slime_dispatch_ipython_pause, a:text, "--", "\n"]
        else
          if exists('b:quarto_is_r_mode') && b:quarto_is_r_mode && b:quarto_is_python_chunk
            return [a:text, "\n"]
          else
            return [a:text]
          end
        end
      endfunction
      ]]

      vim.g.slime_target = 'neovim'
      vim.g.slime_no_mappings = true
      vim.g.slime_python_ipython = 1
    end,
    config = function()
      vim.g.slime_input_pid = false
      vim.g.slime_suggest_default = true
      vim.g.slime_menu_config = false
      vim.g.slime_neovim_ignore_unlisted = true
      vim.b.slime_cell_delimiter = '#\\s\\=%%'

      local function mark_terminal()
        local job_id = vim.b.terminal_job_id
        vim.print('job_id: ' .. job_id)
      end

      local function set_terminal()
        vim.fn.call('slime#config', {})
      end
      vim.keymap.set(
        'n',
        '<leader>jt',
        mark_terminal,
        { desc = 'Slime: mark [t]erminal' }
      )
      vim.keymap.set('n', '<leader>js', function()
        vim.fn['slime#send_cell']()
      end, { desc = 'Slime: [s]end cell' })
    end,
  },
}
