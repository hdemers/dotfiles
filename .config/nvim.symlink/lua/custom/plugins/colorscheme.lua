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
            IblIndent = { fg = colors.base02 },
            IblScope = { fg = colors.magenta },
            TelescopeNormal = { bg = colors.base03 },
            TelescopeBorder = { bg = colors.base03, fg = colors.blue },
            ['@function.builtin'] = { link = 'Special' },
            ['@variable'] = { bg = 'none', fg = 'none' },
            ['@variable.builtin'] = { link = 'Identifier' },
            ['@variable.member'] = { link = '@variable' },
            ['@string.documentation'] = { link = 'String' },
            ['@constant.builtin'] = { link = 'Special' },
            ['@keyword.import'] = { link = 'Keyword' },
            ['@attribute'] = { link = 'Keyword' },
            ['@string.escape'] = { link = 'SpecialChar' },
            Folded = { underline = false },
            TabLine = { underline = false },
            TabLineFill = { underline = false },
            TabLineSel = { underline = false },
            FloatBorder = { bg = colors.base03, fg = colors.blue },
          }
        end,
      }
      vim.o.background = 'dark'
      vim.cmd.colorscheme 'solarized'
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
