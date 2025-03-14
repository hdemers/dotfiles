return {
  -- Detect tabstop and shiftwidth automatically
  { 'tpope/vim-sleuth', enabled = true },
  -- This plugin adds which-key entries for vim-unimpaired, which is a dependency.
  {
    'afreakk/unimpaired-which-key.nvim',
    dependencies = { 'tpope/vim-unimpaired' },
    config = function()
      local wk = require 'which-key'
      wk.add(require 'unimpaired-which-key')
    end,
  },
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
        { '<leader>b', group = '[b]uffer' },
        { '<leader>c', group = '[c]ode' },
        { '<leader>s', group = '[s]earch' },
      }
    end,
    keys = {
      {
        '<leader>?',
        function()
          require('which-key').show { global = false }
        end,
        desc = 'Buffer Local Keymaps (which-key)',
      },
    },
  },

  {
    'echasnovski/mini.nvim',
    config = function()
      -- Better Around/Inside textobjects
      --
      -- Examples:
      --  - va)  - [V]isually select [A]round [)]paren
      --  - yinq - [Y]ank [I]nside [N]ext [']quote
      --  - ci'  - [C]hange [I]nside [']quote
      require('mini.ai').setup { n_lines = 500 }

      -- Add/delete/replace surroundings (brackets, quotes, etc.)
      --
      -- - saiw) - [S]urround [A]dd [I]nner [W]ord [)]Paren
      -- - sd'   - [S]urround [D]elete [']quotes
      -- - sr)'  - [S]urround [R]eplace [)] [']
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

      -- ... and there is more!
      --  Check out: https://github.com/echasnovski/mini.nvim
    end,
  },
  -- Session manager and startup screen
  {
    'echasnovski/mini.files',
    version = false,
    enabled = false,
    config = function(_, opts)
      require('mini.files').setup { opts }
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
    'debugloop/telescope-undo.nvim',
    enabled = false,
    dependencies = { -- note how they're inverted to above example
      {
        'nvim-telescope/telescope.nvim',
        dependencies = { 'nvim-lua/plenary.nvim' },
      },
    },
    keys = {
      { -- lazy style key map
        '<leader>su',
        '<cmd>Telescope undo<cr>',
        desc = '[u]ndo history',
      },
    },
    opts = {
      -- don't use `defaults = { }` here, do this in the main telescope spec
      extensions = {
        undo = {
          side_by_side = true,
          layout_strategy = 'vertical',
          layout_config = {
            preview_height = 0.7,
          },
        },
        -- no other extensions here, they can have their own spec too
      },
    },
    config = function(_, opts)
      -- Calling telescope's setup from multiple specs does not hurt, it will happily merge the
      -- configs for us. We won't use data, as everything is in it's own namespace (telescope
      -- defaults, as well as each extension).
      require('telescope').setup(opts)
      require('telescope').load_extension 'undo'
    end,
  },
  {
    'stevearc/dressing.nvim',
    opts = {},
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
      { "<S-Enter>", function() require("noice").redirect(vim.fn.getcmdline()) end, mode = "c", desc = "Redirect Cmdline" },
      { "<leader>snl", function() require("noice").cmd("last") end, desc = "Noice Last Message" },
      { "<leader>sni", function() require("noice").cmd("history") end, desc = "Noice History" },
      { "<leader>sna", function() require("noice").cmd("all") end, desc = "Noice All" },
      { "<leader>snd", function() require("noice").cmd("dismiss") end, desc = "Dismiss All" },
      { "<c-f>", function() if not require("noice.lsp").scroll(4) then return "<c-f>" end end, silent = true, expr = true, desc = "Scroll forward", mode = {"i", "n", "s"} },
      { "<c-b>", function() if not require("noice.lsp").scroll(-4) then return "<c-b>" end end, silent = true, expr = true, desc = "Scroll backward", mode = {"i", "n", "s"}},
    },
    init = function()
      require('which-key').add {
        { '<leader>sn', group = '[n]oice' },
      }
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
    'folke/zen-mode.nvim',
    opts = {
      -- this will change the font size on alacritty when in zen mode
      -- requires  Alacritty Version 0.10.0 or higher
      -- uses `alacritty msg` subcommand to change font size
      plugins = {
        wezterm = {
          enabled = true,
          font = '+2', -- font size
        },
      },
    },
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
          -- Only load the session if nvim was started with no args
          if vim.fn.argc(-1) == 0 then
            -- Save these to a different directory, so our manual sessions don't get polluted
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
      {
        "t",
        mode = { "n", "x", "o" },
        function() require("flash").jump() end,
        desc = "Flash"
      },
      {
        "T", mode = { "n", "x", "o" }, function() require("flash").treesitter() end, desc = "Flash Treesitter" },
      { "r", mode = "o", function() require("flash").remote() end, desc = "Remote Flash" },
      { "R", mode = { "o", "x" }, function() require("flash").treesitter_search() end, desc = "Treesitter Search" },
      { "<c-s>", mode = { "c" }, function() require("flash").toggle() end, desc = "Toggle Flash Search" },
    },
  },
  {
    'OXY2DEV/markview.nvim',
    enabled = true,
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
        filetypes = { 'markdown', 'quarto', 'rmd', 'Avante' },
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
    'nvim-neo-tree/neo-tree.nvim',
    branch = 'v3.x',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-tree/nvim-web-devicons', -- not strictly required, but recommended
      'MunifTanjim/nui.nvim',
      -- "3rd/image.nvim", -- Optional image support in preview window: See `# Preview Mode` for more information
    },
    keys = {
      {
        '<leader>sx',
        ':Neotree toggle<CR>',
        desc = 'Toggle Neotree',
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
      picker = { enabled = true },
      indent = { enabled = false },
      dashboard = {
        enabled = true,
        width = 120,
        sections = {
          { section = 'header' },
          -- {
          --   pane = 2,
          --   section = 'terminal',
          --   cmd = 'colorscript -e square',
          --   height = 5,
          --   padding = 1,
          -- },
          {
            icon = ' ',
            desc = 'Browse Repo',
            padding = 1,
            key = 'b',
            action = function()
              Snacks.gitbrowse()
            end,
          },
          function()
            local in_git = Snacks.git.get_root() ~= nil
            local cmds = {
              -- {
              --   title = 'Notifications',
              --   cmd = 'gh notify -s -a -n5',
              --   action = function()
              --     vim.ui.open 'https://github.com/notifications'
              --   end,
              --   key = 'n',
              --   icon = ' ',
              --   height = 5,
              --   enabled = true,
              -- },
              -- {
              --   title = 'Open Issues',
              --   cmd = 'gh issue list -L 3',
              --   key = 'i',
              --   action = function()
              --     vim.fn.jobstart('gh issue list --web', { detach = true })
              --   end,
              --   icon = ' ',
              --   height = 7,
              -- },
              {
                icon = ' ',
                title = 'Open PRs',
                cmd = 'gh pr list -L 10',
                key = 'P',
                action = function()
                  vim.fn.jobstart('gh pr list --web', { detach = true })
                end,
                height = 12,
              },
              {
                icon = ' ',
                title = 'Git Status',
                -- cmd = 'git --no-pager diff --stat -B -M -C',
                cmd = 'git status -sb',
                height = 20,
              },
            }
            return vim.tbl_map(function(cmd)
              return vim.tbl_extend('force', {
                section = 'terminal',
                enabled = in_git,
                padding = 1,
                ttl = 5 * 60,
                indent = 3,
              }, cmd)
            end, cmds)
          end,
          { section = 'startup' },
        },
      },
    },
    keys = {
      {
        '<leader>Q',
        function()
          Snacks.bufdelete()
        end,
        desc = 'Delete buffer',
      },
      {
        '<leader>D',
        function()
          Snacks.dashboard()
        end,
        desc = '[d]ashboard',
      },
      {
        '<leader>se',
        function()
          Snacks.explorer.open { autoclose = true }
        end,
        desc = 'file explorer',
      },
      {
        '<leader><leader>',
        function()
          Snacks.picker.buffers()
        end,
        desc = 'buffers',
      },
      {
        '<leader>sf',
        function()
          Snacks.picker.files()
        end,
        desc = '[s]earch [f]iles',
      },
      {
        '<leader>sF',
        function()
          Snacks.picker.files { hidden = true }
        end,
        desc = '[s]earch [F]iles including hidden',
      },
      {
        '<leader>si',
        function()
          Snacks.picker.git_files()
        end,
        desc = '[s]earch g[i]t files',
      },
      {
        '<leader>sc',
        function()
          Snacks.picker.files { cwd = vim.fn.stdpath 'config' }
        end,
        desc = '[s]earch [c]onfig files',
      },
      {
        '<leader>ss',
        function()
          Snacks.picker.smart()
        end,
        desc = '[s]earch [s]mart',
      },
      {
        '<leader>s.',
        function()
          Snacks.picker.recent()
        end,
        desc = '[s]earch recent files ("." for repeat)',
      },
      {
        '<leader>sg',
        function()
          Snacks.picker.grep()
        end,
        desc = 'search with [g]rep',
      },
      {
        '<leader>sG',
        function()
          Snacks.picker.grep { hidden = true }
        end,
        desc = 'search with [G]rep including hidden',
      },
      {
        '<leader>s/',
        function()
          Snacks.picker.grep_buffers()
        end,
        desc = 'search buffers with [g]rep',
      },
      {
        '<leader>sw',
        function()
          Snacks.picker.grep_word()
        end,
        desc = 'grep for [w]ord',
        mode = { 'n', 'x' },
      },
      {
        '<leader>/',
        function()
          Snacks.picker.lines()
        end,
        desc = 'Fuzzy search of current buffer',
      },
      {
        '<leader>sl',
        function()
          Snacks.picker.colorschemes()
        end,
        desc = '[s]earch colorschemes',
      },
      {
        '<leader>sy',
        function()
          Snacks.picker.lsp_workspace_symbols()
        end,
        desc = 'search lsp s[y]mbols',
      },
      {
        '<leader>sY',
        function()
          Snacks.picker.lsp_symbols()
        end,
        desc = 'search lsp document symbols',
      },
      {
        '<leader>sk',
        function()
          Snacks.picker.keymaps()
        end,
        desc = '[s]earch [k]eymaps',
      },
      {
        '<leader>sh',
        function()
          Snacks.picker.help()
        end,
        desc = '[s]earch [h]elp',
      },
      {
        '<leader>sr',
        function()
          Snacks.picker.resume()
        end,
        desc = '[s]earch [r]esume',
      },
      {
        '<leader>su',
        function()
          Snacks.picker.undo()
        end,
        desc = '[s]earch [u]ndo',
      },
      {
        '<leader>sq',
        function()
          Snacks.picker.qflist()
        end,
        desc = '[s]earch [q]uickfix',
      },
      {
        '<leader>sd',
        function()
          Snacks.picker.diagnostics()
        end,
        desc = '[s]earch [d]iagnostics',
      },
      {
        '<leader>sD',
        function()
          Snacks.picker.diagnostics_buffer()
        end,
        desc = '[s]earch [D]iagnostics in buffer',
      },
      {
        '<leader>snh',
        function()
          Snacks.notifier.show_history()
        end,
        desc = '[s]how [n]otification [h]istory',
      },
      {
        '<leader>be',
        function()
          Snacks.zen()
        end,
        desc = '[b]e z[e]n',
      },
      {
        'gr',
        function()
          Snacks.picker.lsp_references()
        end,
        nowait = true,
        desc = '[g]o to [r]eferences',
      },
      {
        'gd',
        function()
          Snacks.picker.lsp_definitions()
        end,
        desc = '[g]o to [d]efinition',
      },
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
          Snacks.toggle.dim():map '<leader>uD'
          Snacks.toggle.zen():map '<leader>uz'
        end,
      })
    end,
  },
}
