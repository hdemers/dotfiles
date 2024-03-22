return {
  {
    'maxmx03/solarized.nvim',
    lazy = false,
    priority = 1000,
    enabled = false,
    config = function()
      require('solarized').setup {
        palette = 'solarized',
        theme = 'default',
        highlights = function(colors, colorhelper)
          local darken = colorhelper.darken
          local lighten = colorhelper.lighten
          local blend = colorhelper.blend

          print 'Custom highlights applied!' -- Confirmation message
          return {
            LineNr = { bg = colors.bg },
            -- CursorLineNr = { bg = colors.base02 },
            -- CursorLine = { bg = colors.base02 },
            -- Function = { fg = colors.blue },
            -- Statement = { fg = colors.green },
            Special = { fg = colors.orange },
            -- Type = { fg = colors.yellow },
            -- Visual = { bg = colors.cyan },
            Identifier = { fg = colors.base0 },
            Delimiter = { fg = colors.orange },
            Keyword = { fg = colors.green },
            LspReferenceRead = { link = 'CursorColumn' },
            LspReferenceText = { link = 'CursorColumn' },
            LspReferenceWrite = { link = 'CursorColumn' },
            functionbuiltin = { link = 'Special' },
            TodoBgTODO = { fg = colors.base03, bg = colors.cyan, bold = true },
            TodoBgFIX = { fg = colors.base03, bg = colors.red, bold = true },
            TodoBgNOTE = { fg = colors.base03, bg = colors.green, bold = true },
            TodoBgWARN = { fg = colors.base03, bg = colors.yellow, bold = true },
            SignColumn = { bg = colors.base03 },
            GitSignsAdd = { bg = colors.base03 },
            GitSignsChange = { bg = colors.base03 },
            GitSignsDelete = { bg = colors.base03 },
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
        set_hl('@variable.builtin', { link = 'Identifier' })
        set_hl('@string.documentation', { link = 'String' })
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
    enabled = true,
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
}
