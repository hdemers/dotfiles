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
        vim.cmd.hi 'clear AerialClassMethod'
        vim.cmd.hi 'clear AerialFunction'
        vim.cmd.hi 'link AerialFunction Function'
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
        { desc = 'Toggle [I]ndent lines' }
      )
      vim.keymap.set(
        'n',
        '<leader>cs',
        ':IBLToggleScope<CR>',
        { desc = 'Toggle [S]cope lines' }
      )
    end,
    init = function() end,
  },
}
