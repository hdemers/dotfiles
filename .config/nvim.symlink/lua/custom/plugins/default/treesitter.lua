return {
  { -- Highlight, edit, and navigate code
    'nvim-treesitter/nvim-treesitter',
    branch = 'main',
    build = ':TSUpdate',
    main = 'nvim-treesitter', -- Sets main module to use for opts
    -- [[ Configure Treesitter ]] See `:help nvim-treesitter`
    opts = {
      -- Autoinstall languages that are not installed
      auto_install = true,
    },
    init = function()
      vim.api.nvim_create_autocmd('FileType', {
        callback = function()
          -- Enable treesitter highlighting and disable regex syntax
          pcall(vim.treesitter.start)
          -- Enable treesitter-based indentation
          vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end,
      })
      local ensureInstalled = {
        'bash',
        'c',
        'diff',
        'html',
        'lua',
        'markdown',
        'sql',
        'vim',
        'vimdoc',
        'python',
        'regex',
      }
      local alreadyInstalled = require('nvim-treesitter.config').get_installed()
      local parsersToInstall = vim
        .iter(ensureInstalled)
        :filter(function(parser)
          return not vim.tbl_contains(alreadyInstalled, parser)
        end)
        :totable()
      require('nvim-treesitter').install(parsersToInstall)
    end,
  },
  {
    'nvim-treesitter/nvim-treesitter-context',
    enabled = false,
    opts = {
      enable = true,
    },
    config = function(_, opts)
      require('treesitter-context').setup {
        opts,
      }
    end,
  },
  {
    'nvim-treesitter/nvim-treesitter-textobjects',
    enabled = true,
    branch = 'main',
    opts = {
      textobjects = {
        select = {
          enable = true,

          -- Automatically jump forward to textobj, similar to targets.vim
          lookahead = true,

          keymaps = {
            -- You can use the capture groups defined in textobjects.scm
            ['af'] = {
              query = '@function.outer',
              desc = 'Select outer part of a function',
            },
            ['if'] = {
              query = '@function.inner',
              desc = 'Select inner part of a function',
            },
            ['ac'] = {
              query = '@class.outer',
              desc = 'Select outer part of a class region',
            },
            ['ic'] = {
              query = '@class.inner',
              desc = 'Select inner part of a class region',
            },
            -- You can also use captures from other query groups like `locals.scm`
            ['as'] = {
              query = '@scope',
              query_group = 'locals',
              desc = 'Select language scope',
            },
            ['ia'] = {
              query = '@parameter.inner',
              desc = 'Select inner parameter',
            },
            ['aa'] = {
              query = '@parameter.outer',
              desc = 'Select outer parameter',
            },
          },
          -- You can choose the select mode (default is charwise 'v')
          --
          -- Can also be a function which gets passed a table with the keys
          -- * query_string: eg '@function.inner'
          -- * method: eg 'v' or 'o'
          -- and should return the mode ('v', 'V', or '<c-v>') or a table
          -- mapping query_strings to modes.
          selection_modes = {
            ['@parameter.outer'] = 'v', -- charwise
            ['@function.outer'] = 'V', -- linewise
            -- ['@class.outer'] = '<c-v>', -- blockwise
          },
          -- If you set this to `true` (default is `false`) then any textobject is
          -- extended to include preceding or succeeding whitespace. Succeeding
          -- whitespace has priority in order to act similarly to eg the built-in
          -- `ap`.
          --
          -- Can also be a function which gets passed a table with the keys
          -- * query_string: eg '@function.inner'
          -- * selection_mode: eg 'v'
          -- and should return true or false
          include_surrounding_whitespace = false,
        },
        move = {
          enable = true,
          set_jumps = true, -- whether to set jumps in the jumplist
          goto_next_start = {
            [']m'] = '@function.outer',
            [']]'] = { query = '@class.inner', desc = 'Next class start' },
            [']z'] = { query = '@fold', query_group = 'folds', desc = 'Next fold' },
          },
          goto_next_end = {
            [']M'] = '@function.outer',
            [']['] = '@class.outer',
          },
          goto_previous_start = {
            ['[m'] = '@function.outer',
            ['[['] = '@class.inner',
          },
          goto_previous_end = {
            ['[M'] = '@function.outer',
            ['[]'] = '@class.outer',
          },
          goto_next = {
            [']w'] = '@conditional.outer',
          },
          goto_previous = {
            ['[w'] = '@conditional.outer',
          },
        },
        swap = {
          enable = true,
          swap_next = {
            [']a'] = '@parameter.inner',
          },
          swap_previous = {
            ['[a'] = '@parameter.inner',
          },
        },
      },
    },
    config = function(_, opts)
      require('nvim-treesitter').setup(opts)
    end,
  },
}
