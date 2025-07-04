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
            FzfLuaBorder = { fg = colors.cyan },
          }
        end,
      }
      vim.o.background = 'dark'
    end,
  },
  {
    'catppuccin/nvim',
    name = 'catppucin',
    lazy = false,
    priority = 1000,
    opts = {
      integrations = {
        diffview = true,
        neotest = true,
        noice = true,
        notify = true,
        overseer = true,
        lsp_trouble = true,
        dadbod_ui = true,
        gitgutter = true,
        which_key = true,
      },
    },
    config = function(_, opts)
      require('catppuccin').setup(opts)
      vim.o.background = 'dark'
      vim.cmd.colorscheme 'catppuccin'
    end,
  },
  {
    'rebelot/kanagawa.nvim',
    opts = {
      colors = {
        theme = {
          all = {
            ui = {
              bg_gutter = 'none',
            },
          },
        },
      },
      overrides = function(colors) -- add/modify highlights
        local theme = colors.theme
        return {
          TelescopeTitle = { fg = theme.ui.special, bold = true },
          TelescopeMatching = { fg = theme.ui.special, bold = true },
          TelescopeSelection = { bg = theme.ui.shade0 },
          TelescopePromptNormal = { bg = theme.ui.bg_p1 },
          TelescopePromptBorder = { fg = theme.ui.bg_p1, bg = theme.ui.bg_p1 },
          TelescopeResultsNormal = { fg = theme.ui.fg_dim, bg = theme.ui.bg_m1 },
          TelescopeResultsBorder = { fg = theme.ui.bg_m1, bg = theme.ui.bg_m1 },
          TelescopePreviewNormal = { bg = theme.ui.bg_dim },
          TelescopePreviewBorder = { bg = theme.ui.bg_dim, fg = theme.ui.bg_dim },
          Pmenu = { fg = theme.ui.shade0, bg = theme.ui.bg_p1 },
          PmenuSel = { fg = 'NONE', bg = theme.ui.bg_p2 },
          PmenuSbar = { bg = theme.ui.bg_m1 },
          PmenuThumb = { bg = theme.ui.bg_p2 },
        }
      end,
    },
    config = function(_, opts)
      require('kanagawa').setup(opts)
    end,
  },
  {
    'folke/tokyonight.nvim',
    opts = {
      style = 'moon',
      on_highlights = function(hl, c)
        local prompt = '#2d3149'

        hl.TelescopeMatching = { link = 'Title' }
        hl.TelescopeSelection = { bg = c.bg_visual }
        hl.TelescopeSelectionCaret = { fg = c.orange }
        hl.MiniStatuslineFilename = { link = 'MiniStatuslineInactive' }
        -- The following are highlights to make Telescope borderless.
        hl.TelescopeNormal = {
          bg = c.bg_dark,
          fg = c.fg_dark,
        }
        hl.TelescopeBorder = {
          bg = c.bg_dark,
          fg = c.bg_dark,
        }
        hl.TelescopePromptNormal = {
          bg = prompt,
        }
        hl.TelescopePromptBorder = {
          bg = prompt,
          fg = prompt,
        }
        hl.TelescopePromptTitle = {
          bg = prompt,
          fg = prompt,
        }
        hl.TelescopePreviewTitle = {
          bg = c.bg_dark,
          fg = c.bg_dark,
        }
        hl.TelescopeResultsTitle = {
          bg = c.bg_dark,
          fg = c.bg_dark,
        }
      end,
    },
  },
  {
    'navarasu/onedark.nvim',
    opts = {
      style = 'darker',
    },
    config = function(_, opts)
      require('onedark').setup(opts)
    end,
  },
  {
    'sainnhe/gruvbox-material',
    config = function()
      vim.api.nvim_create_autocmd('ColorScheme', {
        group = vim.api.nvim_create_augroup('custom_highlights_gruvboxmaterial', {}),
        pattern = 'gruvbox-material',
        callback = function()
          local config = vim.fn['gruvbox_material#get_configuration']()
          local palette = vim.fn['gruvbox_material#get_palette'](
            config.background,
            config.foreground,
            config.colors_override
          )
          local set_hl = vim.fn['gruvbox_material#highlight']

          set_hl('LeapBackdrop', palette.grey1, palette.none)
        end,
      })
    end,
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
  { 'nyoom-engineering/oxocarbon.nvim' },
  {
    'AlexvZyl/nordic.nvim',
    config = function()
      -- local palette = require 'nordic.colors'
      require('nordic').setup {
        ts_context = { dark_background = false },
        telescope = { style = 'flat' },
        on_highlight = function(highlights, palette)
          -- highlights.spell = { link = '@spell' }
          -- highlights.DiagnosticUnderlineError = {}
          highlights.TelescopeMatching = { link = 'IncSearch' }
        end,
      }
    end,
  },
  { 'EdenEast/nightfox.nvim' },
  {
    '0xstepit/flow.nvim',
    opts = {},
    config = function()
      require('flow').setup {
        transparent = false, -- Set transparent background.
        fluo_color = 'pink', --  Fluo color: pink, yellow, orange, or green.
        mode = 'desaturate', -- Intensity of the palette: normal, bright, desaturate, or dark. Notice that dark is ugly!
        aggressive_spell = false, -- Display colors for spell check.
      }
    end,
  },
  {
    'slugbyte/lackluster.nvim',
  },
  { 'projekt0n/github-nvim-theme' },
  {
    'killitar/obscure.nvim',
    lazy = false,
    priority = 1000,
    config = function()
      require('obscure').setup {
        on_highlights = function(hl, c)
          hl.DiffChange = { bg = c.cyan, fg = c.black, underline = false }
        end,
      }
    end,
  },
  { 'fcancelinha/nordern.nvim', branch = 'master' },
  {
    'tiagovla/tokyodark.nvim',
  },
  {
    'yorik1984/newpaper.nvim',
    enabled = false,
    config = function()
      require('newpaper').setup { style = 'dark' }
    end,
  },
  -- Using lazy.nvim
  {
    'ribru17/bamboo.nvim',
    lazy = false,
    priority = 1000,
    config = function()
      require('bamboo').setup {
        -- optional configuration here
      }
    end,
  },
  {
    'neanias/everforest-nvim',
    version = false,
    lazy = false,
    priority = 1000, -- make sure to load this before all the other start plugins
    -- Optional; default configuration will be used if setup isn't called.
    config = function()
      require('everforest').setup {
        -- Your config here
      }
    end,
  },
  {
    '2giosangmitom/nightfall.nvim',
    lazy = false,
    priority = 1000,
    opts = {},
  },
  {
    'sho-87/kanagawa-paper.nvim',
    lazy = false,
    priority = 1000,
    opts = {
      style = 'dark',
      overrides = function(colors)
        return {
          -- Override any highlight group
          -- For example, to change the background color of the cursor line:
          MiniStatuslineDevinfo = { fg = colors.theme.ui.fg_gray },
          MiniStatuslineFilename = { fg = colors.theme.ui.fg },
        }
      end,
    },
    config = function(_, opts)
      require('kanagawa-paper').setup(opts)
    end,
  },
  {
    'ramojus/mellifluous.nvim',
    lazy = false,
    priority = 1000,
  },
  {
    'olimorris/onedarkpro.nvim',
    priority = 1000, -- Ensure it loads first
  },
  {
    'marko-cerovac/material.nvim',
    config = function()
      require('material').setup {
        contrast = {
          terminal = true,
          sidebars = true,
          floating_windows = true,
        },
        plugins = {
          -- "coc",
          -- "colorful-winsep",
          'dap',
          -- "dashboard",
          -- "eyeliner",
          'fidget',
          'flash',
          'gitsigns',
          -- "harpoon",
          -- "hop",
          -- "illuminate",
          'indent-blankline',
          -- "lspsaga",
          'mini',
          'neogit',
          'neotest',
          'neo-tree',
          -- "neorg",
          'noice',
          -- 'nvim-cmp',
          -- "nvim-navic",
          -- "nvim-tree",
          'nvim-web-devicons',
          -- "rainbow-delimiters",
          -- "sneak",
          'telescope',
          'trouble',
          'which-key',
          'nvim-notify',
        },
      }
    end,
  },
  {
    'sainnhe/edge',
    lazy = false,
    priority = 1000,
    config = function()
      -- Optionally configure and load the colorscheme
      -- directly inside the plugin declaration.
      vim.g.edge_enable_italic = true
    end,
  },
  {
    'sainnhe/sonokai',
    lazy = false,
    priority = 1000,
    config = function()
      -- Optionally configure and load the colorscheme
      -- directly inside the plugin declaration.
      vim.g.sonokai_enable_italic = true
    end,
  },
  {
    'uloco/bluloco.nvim',
    lazy = false,
    priority = 1000,
    dependencies = { 'rktjmp/lush.nvim' },
    config = function()
      -- your optional config goes here, see below.
    end,
  },
  {
    'rockyzhang24/arctic.nvim',
    dependencies = { 'rktjmp/lush.nvim' },
    name = 'arctic',
    branch = 'main',
    priority = 1000,
    config = function()
      vim.cmd 'colorscheme arctic'
    end,
  },
  {
    'ficcdaf/ashen.nvim',
    -- optional but recommended,
    -- pin to the latest stable release:
    lazy = false,
    priority = 1000,
    -- configuration is optional!
  },
  { 'HoNamDuong/hybrid.nvim' },
  { 'samharju/synthweave.nvim' },
  { 'Yazeed1s/oh-lucy.nvim' },
}
