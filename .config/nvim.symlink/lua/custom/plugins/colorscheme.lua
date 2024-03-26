return {
  {
    'maxmx03/solarized.nvim',
    lazy = false,
    priority = 1000,
    enabled = true,
    config = function()
      require('solarized').setup {
        palette = 'solarized',
        theme = 'default',
        highlights = function(colors)
          return {
            LineNr = { bg = colors.base03 },
            -- CursorLineNr = { bg = colors.base02 },
            -- CursorLine = { bg = colors.base02 },
            -- Function = { fg = colors.blue },
            -- Statement = { fg = colors.green },
            Special = { fg = colors.orange },
            -- Type = { fg = colors.yellow },
            Visual = { bg = colors.bg, standout = false },
            Identifier = { fg = colors.base0 },
            Delimiter = { fg = colors.orange },
            Keyword = { fg = colors.green, bold = false },
            LspReferenceRead = { link = 'CursorColumn' },
            LspReferenceText = { link = 'CursorColumn' },
            LspReferenceWrite = { link = 'CursorColumn' },
            functionbuiltin = { link = 'Special' },
            TodoBgTODO = { fg = colors.base03, bg = colors.cyan, bold = true },
            TodoFgTODO = { fg = colors.cyan },
            TodoBgFIX = { fg = colors.base03, bg = colors.red, bold = true },
            TodoFgFIX = { fg = colors.red },
            TodoBgNOTE = { fg = colors.base03, bg = colors.green, bold = true },
            TodoBgWARN = { fg = colors.base03, bg = colors.yellow, bold = true },
            SignColumn = { bg = colors.base03 },
            DiagnosticSignError = { bg = colors.base03 },
            DiagnosticSignHint = { bg = colors.base03 },
            DiagnosticSignOk = { bg = colors.base03 },
            DiagnosticSignWarn = { bg = colors.base03 },
            DiagnosticSignInfo = { bg = colors.base03 },
            GitSignsAdd = { bg = colors.base03 },
            GitSignsChange = { bg = colors.base03 },
            GitSignsDelete = { bg = colors.base03 },
            WinSeparator = { bg = colors.base03 },
            DiffAdd = { bg = colors.base02, fg = colors.green, reverse = false },
            DiffChange = { bg = colors.base02, fg = colors.yellow, reverse = false },
            DiffDelete = { bg = colors.base02, fg = colors.red, reverse = false },
            DiffText = { bg = colors.base02, fg = colors.blue, reverse = false },
            MsgSeparator = { bg = colors.base02 },
            EndOfBuffer = { fg = colors.base0 },
            StatusLine = { bg = colors.base02 },
            StatusLineNC = { bg = colors.base02 },
            MiniStatuslineInactive = { bg = colors.base02 },
          }
        end,
      }
      vim.o.background = 'dark' -- or 'light'
      vim.cmd.colorscheme 'solarized'
    end,
    init = function()
      local set_hl = require('solarized.utils').set_hl
      local apply_colors = function()
        -- You can configure highlights by doing something like
        set_hl('@function.builtin', { link = 'Special' })
        set_hl('@variable', {})
        set_hl('@variable.builtin', { link = 'Identifier' })
        set_hl('@variable.member', { link = '@variable' })
        set_hl('@string.documentation', { link = 'String' })
        set_hl('@constant.builtin', { link = 'Special' })
        set_hl('@keyword.import', { link = 'Keyword' })
        set_hl('@attribute', { link = 'Keyword' })
        set_hl('@string.escape', { link = 'SpecialChar' })
      end
      vim.api.nvim_create_autocmd('ColorScheme', {
        pattern = 'solarized',
        desc = 'Custom Solarized colorscheme',
        group = vim.api.nvim_create_augroup('CustomColorscheme', { clear = false }),
        callback = apply_colors,
      })
      apply_colors()
    end,
  },
  { -- You can easily change to a different colorscheme.
    -- Change the name of the colorscheme plugin below, and then
    -- change the command in the config to whatever the name of that colorscheme is
    --
    -- If you want to see what colorschemes are already installed, you can use `:Telescope colorscheme`
    'ishan9299/nvim-solarized-lua',
    priority = 1000, -- make sure to load this before all the other start plugins
    enabled = false,
    init = function()
      -- Load the colorscheme here.
      -- Like many other themes, this one has different styles, and you could load
      -- any other, such as 'tokyonight-storm', 'tokyonight-moon', or 'tokyonight-day'.
      vim.cmd.colorscheme 'solarized-flat'
      local apply_colors = function()
        -- You can configure highlights by doing something like
        vim.cmd.hi 'Comment gui=none'
        vim.cmd.hi 'LspReferenceRead gui=none guibg=#073642'
        vim.cmd.hi 'LspReferenceText gui=none guibg=#073642'
        vim.cmd.hi 'LspReferenceWrite gui=none guibg=#073642'
        vim.cmd.hi 'GitSignsAdd guibg=none'
        vim.cmd.hi 'GitSignsDelete guibg=none'
        vim.cmd.hi 'GitSignsChange guibg=none'
        vim.cmd.hi 'TodoBgTODO gui=bold guifg=#002b36 guibg=#2aa198'
        vim.cmd.hi 'TodoBgFIX gui=bold guifg=#002b36 guibg=#dc322f'
        vim.cmd.hi 'link @variable NONE'
        vim.cmd.hi 'link @constructor Function'
        vim.cmd.hi 'link @variable.builtin Identifier'
        vim.cmd.hi 'link @attribute Keyword'
        -- Indent blank lines plugin highlights.
        vim.cmd.hi 'IblIndent guifg=#073642'
        vim.cmd.hi 'link IblScope LineNr'
        vim.cmd.hi 'TelescopeBorder guifg=#2aa198'
        -- vim.cmd.hi 'DiagnosticUnderlineWarn '
      end
      vim.api.nvim_create_autocmd('ColorScheme', {
        pattern = 'solarized-*',
        desc = 'Custom Solarized colorscheme',
        group = vim.api.nvim_create_augroup('CustomColorscheme', { clear = false }),
        callback = apply_colors,
      })
      apply_colors()
    end,
  },
  {
    'catppuccin/nvim',
    priority = 1000, -- make sure to load this before all the other start plugins
    name = 'catppucin',
  },
  {
    'rebelot/kanagawa.nvim',
    priority = 1000, -- make sure to load this before all the other start plugins
  },
  {
    'folke/tokyonight.nvim',
    lazy = false,
    priority = 1000,
    opts = { style = 'moon' },
  },
  {
    'navarasu/onedark.nvim',
    opts = {
      style = 'darker',
    },
  },
  {
    'sainnhe/gruvbox-material',
  },
  {
    'kepano/flexoki-neovim',
    name = 'flexoki',
    init = function()
      local apply_colors = function()
        vim.cmd.hi 'GitSignsAdd guifg=#879a39 guibg=none'
        vim.cmd.hi 'GitSignsChange guifg=#8b7ec8 guibg=none'
        vim.cmd.hi 'GitSignsDelete guifg=#d14d41 guibg=none'
        vim.cmd.hi 'GitSignsText guifg=#205ea6 guibg=none'
      end
      vim.api.nvim_create_autocmd('ColorScheme', {
        pattern = 'flexoki-dark',
        desc = 'Custom flexoki colorscheme',
        group = vim.api.nvim_create_augroup('CustomColorscheme', { clear = false }),
        callback = apply_colors,
      })
    end,
  },
  { 'savq/melange-nvim' },
}
