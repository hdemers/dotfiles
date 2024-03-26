return {
  {
    -- A code outline window for skimming and quick navigation
    'stevearc/aerial.nvim',
    opts = {
      -- optionally use on_attach to set keymaps when aerial has attached to a buffer
      -- on_attach = function(bufnr)
      -- Jump forwards/backwards with '{' and '}'
      -- vim.keymap.set("n", "{", "<cmd>AerialPrev<CR>", { buffer = bufnr })
      -- vim.keymap.set("n", "}", "<cmd>AerialNext<CR>", { buffer = bufnr })
      -- end,
      backends = { 'treesitter' },
      filter_kind = false,
      layout = {
        default_direction = 'prefer_right',
        placement = 'window',
      },
      close_automatic_events = { 'switch_buffer' },

      show_guides = true,
      nav = {
        border = 'rounded',
        max_height = 0.9,
        min_height = { 10, 0.5 },
        max_width = 0.5,
        min_width = { 0.2, 20 },
        win_opts = {
          cursorline = true,
          winblend = 10,
        },
        -- Jump to symbol in source window when the cursor moves
        autojump = false,
        -- Show a preview of the code in the right column, when there are no child symbols
        preview = true,
        icons = {
          Function = '',
          Method = '',
          Variable = '',
          Constructor = '',
          Field = 'ﰠ',
          Interface = '',
          Module = '',
          Property = '襁',
        },
      },
    },
    -- Optional dependencies
    dependencies = {
      'nvim-treesitter/nvim-treesitter',
      'nvim-tree/nvim-web-devicons',
    },
    cmd = { 'AerialToggle', 'AerialOpen', 'AerialClose', 'AerialRefresh' },
    init = function()
      local colors = function()
        vim.cmd.hi 'clear AerialClass'
        vim.cmd.hi 'link AerialClass Structure'
        vim.cmd.hi 'link AerialClassIcon Structure'
        vim.cmd.hi 'clear AerialClassMethod'
        vim.cmd.hi 'clear AerialFunction'
        vim.cmd.hi 'link AerialFunction Function'
        vim.cmd.hi 'clear AerialFunctionIcon'
        vim.cmd.hi 'link AerialFunctionIcon Function'
        vim.cmd.hi 'clear AerialMethod'
        vim.cmd.hi 'link AerialMethod Special'
        vim.cmd.hi 'clear AerialVariable'
        vim.cmd.hi 'link AerialVariable Normal'
        vim.cmd.hi 'clear AerialConstructor'
        vim.cmd.hi 'link AerialConstructor Function'
        vim.cmd.hi 'clear AerialModule'
        vim.cmd.hi 'link AerialModule Normal'
        vim.cmd.hi 'clear AerialProperty'
        vim.cmd.hi 'link AerialProperty Identifier'
      end
      vim.api.nvim_create_autocmd('ColorSchemePre', {
        pattern = '*',
        desc = 'Better colorscheme',
        group = vim.api.nvim_create_augroup('CustomColorscheme', { clear = false }),
        callback = colors,
      })
      colors()
    end,
  },
  -- Highlight todo, notes, etc in comments
  {
    'folke/todo-comments.nvim',
    event = 'VimEnter',
    dependencies = { 'nvim-lua/plenary.nvim' },
    opts = { signs = false },
  },
  { -- Add indentation guides even on blank lines
    'lukas-reineke/indent-blankline.nvim',
    -- Enable `lukas-reineke/indent-blankline.nvim`
    -- See `:help ibl`
    main = 'ibl',
    opts = {
      enabled = false,
      scope = { enabled = false },
    },
    config = function()
      vim.keymap.set(
        'n',
        '<leader>ci',
        ':IBLToggle<CR> :IBLToggleScope<CR>',
        { desc = 'IBL: toggle [i]ndent lines' }
      )
      vim.keymap.set(
        'n',
        '<leader>cs',
        ':IBLToggleScope<CR>',
        { desc = 'IBL: toggle [s]cope lines' }
      )
    end,
    init = function() end,
  },
  { -- Linting
    'mfussenegger/nvim-lint',
    event = { 'BufReadPre', 'BufNewFile' },
    config = function()
      local lint = require 'lint'
      lint.linters_by_ft = {
        -- markdown = { 'markdownlint' },
        python = { 'mypy' },
      }

      -- To allow other plugins to add linters to require('lint').linters_by_ft,
      -- instead set linters_by_ft like this:
      -- lint.linters_by_ft = lint.linters_by_ft or {}
      -- lint.linters_by_ft['markdown'] = { 'markdownlint' }
      --
      -- However, note that this will enable a set of default linters,
      -- which will cause errors unless these tools are available:
      -- {
      --   clojure = { "clj-kondo" },
      --   dockerfile = { "hadolint" },
      --   inko = { "inko" },
      --   janet = { "janet" },
      --   json = { "jsonlint" },
      --   markdown = { "vale" },
      --   rst = { "vale" },
      --   ruby = { "ruby" },
      --   terraform = { "tflint" },
      --   text = { "vale" }
      -- }
      --
      -- You can disable the default linters by setting their filetypes to nil:
      -- lint.linters_by_ft['clojure'] = nil
      -- lint.linters_by_ft['dockerfile'] = nil
      -- lint.linters_by_ft['inko'] = nil
      -- lint.linters_by_ft['janet'] = nil
      -- lint.linters_by_ft['json'] = nil
      -- lint.linters_by_ft['markdown'] = nil
      -- lint.linters_by_ft['rst'] = nil
      -- lint.linters_by_ft['ruby'] = nil
      -- lint.linters_by_ft['terraform'] = nil
      -- lint.linters_by_ft['text'] = nil

      -- Create autocommand which carries out the actual linting
      -- on the specified events.
      local lint_augroup = vim.api.nvim_create_augroup('lint', { clear = true })
      vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWritePost', 'InsertLeave' }, {
        group = lint_augroup,
        callback = function()
          require('lint').try_lint()
        end,
      })
    end,
  },
}
