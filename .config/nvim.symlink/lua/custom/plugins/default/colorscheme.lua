return {
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
      -- vim.o.background = 'dark'
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
  {
    'vague2k/vague.nvim',
    config = function()
      -- NOTE: you do not need to call setup if you don't want to.
      require('vague').setup {
        -- optional configuration here
      }
    end,
  },
  {
    'ray-x/aurora',
    init = function()
      vim.g.aurora_italic = 1
      vim.g.aurora_transparent = 1
      vim.g.aurora_bold = 1
    end,
    config = function()
      vim.api.nvim_set_hl(0, '@number', { fg = '#e933e3' })
    end,
  },
}
