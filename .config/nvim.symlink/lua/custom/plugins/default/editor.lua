return {
  -- Detect tabstop and shiftwidth automatically
  { 'tpope/vim-sleuth', enabled = true },
  -- This plugin adds which-key entries for vim-unimpaired, which is a dependency.
  -- {
  --   'afreakk/unimpaired-which-key.nvim',
  --   dependencies = { 'tpope/vim-unimpaired' },
  --   config = function()
  --     local wk = require 'which-key'
  --     wk.add(require 'unimpaired-which-key')
  --   end,
  -- },
  { -- Useful plugin to show you pending keybinds.
    'folke/which-key.nvim',
    event = 'VeryLazy',
    opts = {
      preset = 'modern',
    },
    init = function()
      local wk = require 'which-key'

      -- Document existing key chains
      wk.add {
        { '<leader>b', group = 'Buffer' },
        { '<leader>c', group = 'Code' },
        { '<leader>s', group = 'Search' },
        { '<leader>a', group = 'AI' },
      }
    end,
    keys = {
      {
        '<leader>?',
        function()
          require('which-key').show { global = false }
        end,
        desc = 'Buffer local keymaps (which-key)',
      },
    },
  },

  {
    'echasnovski/mini.nvim',
    lazy = false,
    keys = {
      {
        '<leader>se',
        function()
          require('mini.files').open()
        end,
        desc = 'search explorer',
      },
    },
    config = function()
      -- Better Around/Inside textobjects
      require('mini.ai').setup { n_lines = 500 }

      -- Add/delete/replace surroundings (brackets, quotes, etc.)
      require('mini.surround').setup {
        -- Module mappings. Use `''` (empty string) to disable one.
        mappings = {
          add = 'gsa', -- Add surrounding in Normal and Visual modes
          delete = 'gsd', -- Delete surrounding
          find = 'gsf', -- Find surrounding (to the right)
          find_left = 'gsF', -- Find surrounding (to the left)
          highlight = 'gsh', -- Highlight surrounding
          replace = 'gsr', -- Replace surrounding
          update_n_lines = 'gsn', -- Update `n_lines`

          suffix_last = 'l', -- Suffix to search with "prev" method
          suffix_next = 'n', -- Suffix to search with "next" method
        },
      }
      -- File explorer
      require('mini.files').setup()
      -- Go forward/backward with square brackets
      require('mini.bracketed').setup {
        -- First-level elements are tables describing behavior of a target:
        --
        -- - <suffix> - single character suffix. Used after `[` / `]` in mappings.
        --   For example, with `b` creates `[B`, `[b`, `]b`, `]B` mappings.
        --   Supply empty string `''` to not create mappings.
        --
        -- - <options> - table overriding target options.
        --
        -- See `:h MiniBracketed.config` for more info.
        buffer = { suffix = '', options = {} },
        comment = { suffix = '', options = {} },
        conflict = { suffix = 'x', options = {} },
        diagnostic = { suffix = '', options = {} },
        file = { suffix = '', options = {} },
        indent = { suffix = '', options = {} },
        jump = { suffix = '', options = {} },
        location = { suffix = '', options = {} },
        oldfile = { suffix = 'o', options = {} },
        quickfix = { suffix = '', options = {} },
        treesitter = { suffix = '', options = {} },
        undo = { suffix = '', options = {} },
        window = { suffix = '', options = {} },
        yank = { suffix = '', options = {} },
      }

      -- Simple and easy statusline.
      --  You could remove this setup call if you don't like it,
      --  and try some other statusline plugin
      local statusline = require 'mini.statusline'
      -- set use_icons to true if you have a Nerd Font
      statusline.setup { use_icons = vim.g.have_nerd_font }

      -- You can configure sections in the statusline by overriding their
      -- default behavior. For example, here we set the section for
      -- cursor location to LINE:COLUMN
      statusline.section_location = function()
        local tasks = require('overseer.task_list').list_tasks { unique = false }
        local tasks_by_status = require('overseer.util').tbl_group_by(tasks, 'status')
        -- If we have running tasks, show them in the statusline
        local line = '%2l:%-2v'
        if tasks_by_status.RUNNING then
          line = line .. ' ▶ ' .. #tasks_by_status.RUNNING
        end
        if tasks_by_status.FAILURE then
          line = line .. ' ✗ ' .. #tasks_by_status.FAILURE
        end
        if tasks_by_status.SUCCESS then
          line = line .. ' ✔ ' .. #tasks_by_status.SUCCESS
        end
        return line
      end
      -- Remove the file info section. Don't need that.
      statusline.section_fileinfo = function()
        return ''
      end
    end,
  },
  {
    'stevearc/oil.nvim',
    enabled = true,
    ---@module 'oil'
    ---@type oil.SetupOpts
    opts = {},
    -- Optional dependencies
    -- dependencies = { { 'echasnovski/mini.icons', opts = {} } },
    dependencies = { 'nvim-tree/nvim-web-devicons' }, -- use if prefer nvim-web-devicons
    config = function(_, opts)
      require('oil').setup(opts)
      vim.keymap.set('n', '-', '<CMD>Oil<CR>', { desc = 'Open parent directory' })
    end,
  },
  {
    'rcarriga/nvim-notify',
    enabled = true,
    keys = {},
    opts = {
      render = 'compact',
      timeout = 3000,
      max_height = function()
        return math.floor(vim.o.lines * 0.75)
      end,
      max_width = function()
        return math.floor(vim.o.columns * 0.75)
      end,
      on_open = function(win)
        vim.api.nvim_win_set_config(win, { zindex = 100 })
      end,
      -- top_down = false,
    },
    config = function(_, opts)
      local stages_util = require 'notify.stages.util'

      -- Custom stages to show notifications at the bottom left of the screen.
      local stages = {
        function(state)
          local next_row = stages_util.available_slot(
            state.open_windows,
            state.message.height + 2,
            stages_util.DIRECTION.BOTTOM_UP
          )

          if not next_row then
            return nil
          end

          return {
            relative = 'editor',
            anchor = 'NE',
            width = state.message.width,
            height = state.message.height,
            col = 1,
            row = next_row,
            border = 'rounded',
            style = 'minimal',
            opacity = 0,
          }
        end,
        function(state, win)
          return {
            opacity = { 100 },
            col = { 1 },
            row = {
              stages_util.slot_after_previous(
                win,
                state.open_windows,
                stages_util.DIRECTION.BOTTOM_UP
              ),
              frequency = 3,
              complete = function()
                return true
              end,
            },
          }
        end,
        function(state, win)
          return {
            col = { 1 },
            time = true,
            row = {
              stages_util.slot_after_previous(
                win,
                state.open_windows,
                stages_util.DIRECTION.BOTTOM_UP
              ),
              frequency = 3,
              complete = function()
                return true
              end,
            },
          }
        end,
        function(state, win)
          return {
            width = {
              1,
              frequency = 2.5,
              damping = 0.9,
              complete = function(cur_width)
                return cur_width < 3
              end,
            },
            opacity = {
              0,
              frequency = 2,
              complete = function(cur_opacity)
                return cur_opacity <= 4
              end,
            },
            col = { 1 },
            row = {
              stages_util.slot_after_previous(
                win,
                state.open_windows,
                stages_util.DIRECTION.BOTTOM_UP
              ),
              frequency = 3,
              complete = function()
                return true
              end,
            },
          }
        end,
      }

      opts.stages = stages
      require('notify').setup(opts)
    end,
  },
  {
    'folke/noice.nvim',
    event = 'VeryLazy',
    dependencies = {
      -- if you lazy-load any plugin below, make sure to add proper `module="..."` entries
      'MunifTanjim/nui.nvim',
      -- OPTIONAL:
      --   `nvim-notify` is only needed, if you want to use the notification view.
      --   If not available, we use `mini` as the fallback
      'rcarriga/nvim-notify',
    },
    opts = {
      lsp = {
        override = {
          ['vim.lsp.util.convert_input_to_markdown_lines'] = true,
          ['vim.lsp.util.stylize_markdown'] = true,
          ['cmp.entry.get_documentation'] = true,
        },
      },
      routes = {
        {
          filter = {
            event = 'msg_show',
            any = {
              { find = '%d+L, %d+B' },
              { find = '; after #%d+' },
              { find = '; before #%d+' },
            },
          },
          view = 'mini',
        },
      },
      presets = {
        bottom_search = true,
        command_palette = true,
        long_message_to_split = true,
        inc_rename = true,
      },
      cmdline = {
        format = {
          cmdline = {
            icon = '>',
          },
        },
      },
    },
    -- stylua: ignore
    keys = {
      -- { '<S-Enter>', function() require('noice').redirect(vim.fn.getcmdline()) end, mode = 'c', desc = 'Redirect Cmdline', },
      { '<leader>snl', function() require('noice').cmd 'last' end, desc = 'Noice Last Message', },
      { '<leader>sni', function() require('noice').cmd 'history' end, desc = 'Noice History', },
      { '<leader>sna', function() require('noice').cmd 'all' end, desc = 'Noice All', },
      { '<leader>snd', function() require('noice').cmd 'dismiss' end, desc = 'Dismiss All', },
      {
        '<c-f>',
        function()
          if not require('noice.lsp').scroll(4) then
            return '<c-f>'
          end
        end,
        silent = true,
        expr = true,
        desc = 'Scroll forward',
        mode = { 'i', 'n', 's' },
      },
      {
        '<c-b>',
        function()
          if not require('noice.lsp').scroll(-4) then
            return '<c-b>'
          end
        end,
        silent = true,
        expr = true,
        desc = 'Scroll backward',
        mode = { 'i', 'n', 's' },
      },
    },
    init = function()
      require('which-key').add { { '<leader>sn', group = 'Noice' } }
    end,
  },
  {
    'ggandor/leap.nvim',
    enabled = false,
    config = function()
      vim.keymap.set({ 'n', 'x', 'o' }, 'f', '<Plug>(leap)')
      -- vim.keymap.set({ 'n', 'x', 'o' }, 'F', '<Plug>(leap-backward)')
      vim.keymap.set({ 'n', 'x', 'o' }, 'gl', '<Plug>(leap-from-window)')
    end,
  },
  {
    'tzachar/highlight-undo.nvim',
    enabled = false,
    opts = {
      duration = 700,
      undo = {
        hlgroup = 'CurSearch',
        mode = 'n',
        lhs = 'u',
        map = 'undo',
        opts = {},
      },
      redo = {
        hlgroup = 'IncSearch',
        mode = 'n',
        lhs = '<C-r>',
        map = 'redo',
        opts = {},
      },
      highlight_for_count = true,
    },
  },
  {
    'stevearc/resession.nvim',
    opts = {
      autosave = {
        enabled = true,
        interval = 60,
        notify = false,
      },
      extensions = {
        plugin = {},
      },
    },
    config = function(_, opts)
      local resession = require 'resession'
      resession.setup(opts)

      -- Load a dir-specific session when we open Neovim, save it when we exit.
      vim.api.nvim_create_autocmd('VimEnter', {
        callback = function()
          local argc = vim.fn.argc(-1)
          local argv = vim.v.argv
          local has_options = false
          for i = 2, #argv do
            if argv[i]:sub(1, 1) == '-' and argv[i] ~= '--embed' then
              has_options = true
              break
            end
          end
          if argc == 0 and not has_options then
            resession.load(vim.fn.getcwd(), { dir = 'dirsession', silence_errors = true })
          end
        end,
        nested = true,
      })

      vim.api.nvim_create_autocmd('VimLeavePre', {
        callback = function()
          resession.save(vim.fn.getcwd(), { dir = 'dirsession', notify = false })
        end,
      })
    end,
  },
  {
    'folke/flash.nvim',
    event = 'VeryLazy',
    ---@type Flash.Config
    opts = {
      modes = {
        char = {
          keys = { 'f', 'F', ';', ',' },
        },
      },
    },
    -- stylua: ignore
    keys = {
      { 't', mode = { 'n', 'x', 'o' }, function() require('flash').jump() end, desc = 'Flash', },
      { 'T', mode = { 'n', 'x', 'o' }, function() require('flash').treesitter() end, desc = 'Flash Treesitter', },
      { 'r', mode = 'o', function() require('flash').remote() end, desc = 'Remote Flash', },
      { 'R', mode = { 'o', 'x' }, function() require('flash').treesitter_search() end, desc = 'Treesitter Search', },
      { '<c-s>', mode = { 'c' }, function() require('flash').toggle() end, desc = 'Toggle Flash Search', },
    },
  },
  {
    'OXY2DEV/markview.nvim',
    enabled = false,
    lazy = false, -- Recommended
    dependencies = {
      -- You will not need this if you installed the
      -- parsers manually
      -- Or if the parsers are in your $RUNTIMEPATH
      {
        'nvim-treesitter/nvim-treesitter',
        -- Treesitter thought it was a good idea to remove the registration of quarto.
        -- This broke markview, otter and probably a bunch of other plugins.
        -- commit = 'ef52e44bb24161e5138b3de5beadab3f3fcff233',
      },
      'nvim-tree/nvim-web-devicons',
    },
    opts = {
      preview = {
        filetypes = { 'markdown', 'quarto', 'rmd', 'Avante', 'codecompanion' },
        modes = { 'n', 'i', 'no', 'c' },
        callbacks = {
          on_enable = function(_, win)
            vim.wo[win].conceallevel = 2
            vim.wo[win].concealcursor = 'nc'
          end,
        },
        hybrid_modes = { 'i', 'v' },
      },
      code_blocks = {
        style = 'simple',
        sign = false,
        -- icons = '',
      },
      checkboxes = {
        enable = false,
      },
      markdown = {
        list_items = {
          enable = true,
          marker_minus = {
            text = '•',
          },
        },
        headings = {
          heading_1 = {
            sign = ' ',
            icon = '█ ',
          },
          heading_2 = {
            sign = ' ',
            icon = '▊ ',
          },
          heading_3 = {
            sign = ' ',
            icon = '▌ ',
          },
          heading_4 = {
            sign = ' ',
            icon = '▎ ',
          },
        },
      },
    },
    config = function(_, opts)
      require('markview').setup(opts)
    end,
  },
  {
    'MeanderingProgrammer/render-markdown.nvim',
    dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-tree/nvim-web-devicons' }, -- if you prefer nvim-web-devicons
    ---@module 'render-markdown'
    ---@type render.md.UserConfig
    opts = {
      file_types = {
        'markdown',
        'quarto',
        'rmd',
        'codecompanion',
        'copilot-chat',
        'Avante',
      },
      code = {
        -- style = 'normal',
        language_name = false,
        language_icon = false,
        language_pad = 0,
        sign = false,
        border = 'thin',
      },
    },
  },
  {
    'nvim-neo-tree/neo-tree.nvim',
    branch = 'v3.x',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-tree/nvim-web-devicons', -- not strictly required, but recommended
      'MunifTanjim/nui.nvim',
      -- "3rd/image.nvim", -- Optional image support in preview window: See `# Preview Mode` for more information
    },
    cmd = { 'Neotree' },
    keys = {
      {
        '<leader>sx',
        ':Neotree toggle<CR>',
        desc = 'Toggle Neo-tree',
      },
    },
    opts = {
      filesystem = {
        follow_current_file = true,
        use_libuv_file_watcher = true,
      },
    },
  },
  {
    'folke/snacks.nvim',
    priority = 1000,
    lazy = false,
    opts = {
      styles = {},
      bigfile = { enabled = true },
      bufdelete = { enabled = true },
      notifier = {
        enabled = true,
        style = 'fancy',
        top_down = false,
        layout = { top = 1 },
      },
      quickfile = { enabled = true },
      statuscolumn = { enabled = true },
      words = { enabled = true },
      scroll = { enabled = true },
      picker = {
        win = {
          -- input window
          input = {
            keys = {
              ['<C-\\>'] = { { 'pick_win', 'jump' }, mode = { 'n', 'i' } },
            },
          },
        },
      },
      indent = { enabled = false },
      dashboard = { enabled = true },
    },
    -- stylua: ignore
    keys = { { '<leader>Q', function() Snacks.bufdelete() end, desc = 'Delete buffer' },
      { '<leader><leader>', function() Snacks.picker.buffers() end, desc = 'Buffers', },
      { '<leader>sf', function() Snacks.picker.files() end, desc = 'Search files', },
      { '<leader>sF', function() Snacks.picker.files { hidden = true } end, desc = 'Search files including hidden', },
      { '<leader>si', function() Snacks.picker.git_files() end, desc = 'Search git files', },
      { '<leader>sc', function() Snacks.picker.files { cwd = vim.fn.stdpath 'config' } end, desc = 'Search config files', },
      { '<leader>ss', function() Snacks.picker.smart() end, desc = 'Search smart', },
      { '<leader>s.', function() Snacks.picker.recent() end, desc = 'Search recent files ("." for repeat)', },
      { '<leader>sg', function() Snacks.picker.grep() end, desc = 'Search with grep', },
      { '<leader>sG', function() Snacks.picker.grep { hidden = true } end, desc = 'Search with grep including hidden', },
      { '<leader>s/', function() Snacks.picker.grep_buffers() end, desc = 'Search buffers with grep', },
      { '<leader>sw', function() Snacks.picker.grep_word() end, desc = 'Grep for word', mode = { 'n', 'x' }, },
      { '<leader>/', function() Snacks.picker.lines() end, desc = 'Fuzzy search of current buffer', },
      { '<leader>sl', function() Snacks.picker.colorschemes() end, desc = 'Search colorschemes', },
      { '<leader>sa', function() Snacks.picker.highlights() end, desc = 'Search highlights', },
      { 'gW', function() Snacks.picker.lsp_workspace_symbols() end, desc = 'Search lsp symbols', },
      { 'gO', function() Snacks.picker.lsp_symbols() end, desc = 'Search lsp document symbols', },
      { '<leader>sk', function() Snacks.picker.keymaps() end, desc = 'Search keymaps', },
      { '<leader>sh', function() Snacks.picker.help() end, desc = 'Search help', },
      { '<leader>sr', function() Snacks.picker.resume() end, desc = 'Search resume', },
      { '<leader>su', function() Snacks.picker.undo() end, desc = 'Search undo', },
      { '<leader>sq', function() Snacks.picker.qflist() end, desc = 'Search quickfix', },
      { '<leader>sd', function() Snacks.picker.diagnostics() end, desc = 'Search diagnostics', },
      { '<leader>sD', function() Snacks.picker.diagnostics_buffer() end, desc = 'Search diagnostics in buffer', },
      { '<leader>snh', function() Snacks.notifier.show_history() end, desc = 'Show notification history', },
      { 'grr', function() Snacks.picker.lsp_references() end, nowait = true, desc = 'Go to references', },
      { 'gd', function() Snacks.picker.lsp_definitions() end, desc = 'Go to definition', },
    },
    init = function()
      vim.api.nvim_create_autocmd('User', {
        pattern = 'VeryLazy',
        callback = function()
          -- Setup some globals for debugging (lazy-loaded)
          _G.dd = function(...)
            Snacks.debug.inspect(...)
          end
          _G.bt = function()
            Snacks.debug.backtrace()
          end
          vim.print = _G.dd -- Override print to use snacks for `:=` command

          -- Create some toggle mappings
          local wk = require 'which-key'
          wk.add {
            { '<leader>u', group = 'Toggles' },
          }
          Snacks.toggle.option('spell', { name = 'Spelling' }):map '<leader>us'
          Snacks.toggle.option('wrap', { name = 'Wrap' }):map '<leader>uw'
          Snacks.toggle
            .option('relativenumber', { name = 'Relative Number' })
            :map '<leader>uL'
          Snacks.toggle.diagnostics():map '<leader>ud'
          Snacks.toggle.line_number():map '<leader>ul'
          Snacks.toggle
            .option(
              'conceallevel',
              { off = 0, on = vim.o.conceallevel > 0 and vim.o.conceallevel or 2 }
            )
            :map '<leader>uc'
          Snacks.toggle.treesitter():map '<leader>uT'
          Snacks.toggle
            .option('background', { off = 'light', on = 'dark', name = 'Dark Background' })
            :map '<leader>ub'
          Snacks.toggle.inlay_hints():map '<leader>uh'
          Snacks.toggle.indent():map '<leader>ug'
          Snacks.toggle.dim():map '<leader>um'
          Snacks.toggle.zen():map '<leader>uz'
          Snacks.toggle
            .option('cursorcolumn', { name = 'Cursor column' })
            :map '<leader>uo'
          Snacks.toggle.option('cursorline', { name = 'Cursor line' }):map '<leader>ur'
        end,

        vim.keymap.set('n', '<leader>uD', function()
          local bufnr = vim.api.nvim_get_current_buf()
          vim.diagnostic.enable(
            not vim.diagnostic.is_enabled { bufnr = bufnr },
            { bufnr = bufnr }
          )
        end, { desc = 'Toggle diagnostics for current buffer' }),
      })
    end,
  },
  {
    'coffebar/transfer.nvim',
    lazy = true,
    cmd = {
      'TransferInit',
      'DiffRemote',
      'TransferUpload',
      'TransferDownload',
      'TransferDirDiff',
      'TransferRepeat',
    },
    opts = {},
  },
  {
    -- Complement to https://github.com/hiasr/vim-zellij-navigator
    'swaits/zellij-nav.nvim',
    enabled = false,
    lazy = true,
    event = 'VeryLazy',
    keys = {
      {
        '<c-h>',
        '<cmd>ZellijNavigateLeftTab<cr>',
        { silent = true, desc = 'navigate left or tab' },
      },
      {
        '<c-j>',
        '<cmd>ZellijNavigateDown<cr>',
        { silent = true, desc = 'navigate down' },
      },
      {
        '<c-k>',
        '<cmd>ZellijNavigateUp<cr>',
        { silent = true, desc = 'navigate up' },
      },
      {
        '<c-l>',
        '<cmd>ZellijNavigateRightTab<cr>',
        { silent = true, desc = 'navigate right or tab' },
      },
    },
    opts = {},
  },
}
