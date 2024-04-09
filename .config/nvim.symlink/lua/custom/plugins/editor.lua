return {
  -- Detect tabstop and shiftwidth automatically
  { 'tpope/vim-sleuth' },
  -- This plugin adds which-key entries for vim-unimpaired, which is a dependency.
  {
    'afreakk/unimpaired-which-key.nvim',
    dependencies = { 'tpope/vim-unimpaired' },
    config = function()
      local wk = require 'which-key'
      local uwk = require 'unimpaired-which-key'
      wk.register(uwk.normal_mode)
      wk.register(uwk.normal_and_visual_mode, { mode = { 'n', 'v' } })
    end,
  },
  -- "gc" to comment visual regions/lines
  { 'numToStr/Comment.nvim', opts = {} },

  { -- Useful plugin to show you pending keybinds.
    'folke/which-key.nvim',
    event = 'VimEnter', -- Sets the loading event to 'VimEnter'
    config = function() -- This is the function that runs, AFTER loading
      require('which-key').setup()

      -- Document existing key chains
      require('which-key').register {
        ['<leader>c'] = { name = '[C]ode', _ = 'which_key_ignore' },
        ['<leader>d'] = { name = '[D]ocument', _ = 'which_key_ignore' },
        ['<leader>r'] = { name = '[R]ename', _ = 'which_key_ignore' },
        ['<leader>s'] = { name = '[S]earch', _ = 'which_key_ignore' },
        ['<leader>w'] = { name = '[W]orkspace', _ = 'which_key_ignore' },
      }
    end,
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
          add = 'Sa', -- Add surrounding in Normal and Visual modes
          delete = 'Sd', -- Delete surrounding
          find = 'Sf', -- Find surrounding (to the right)
          find_left = 'SF', -- Find surrounding (to the left)
          highlight = 'Sh', -- Highlight surrounding
          replace = 'Sr', -- Replace surrounding
          update_n_lines = 'Sn', -- Update `n_lines`

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
        return '%2l:%-2v'
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
    'mhinz/vim-startify',
    init = function()
      vim.g.startify_session_persistence = 1
      vim.g.startify_session_savevars = {
        'g:startify_session_savevars',
        'g:startify_session_savecmds',
      }
      vim.g.startify_change_to_vcs_root = 1
      vim.g.startify_lists = {
        { type = 'sessions', header = { '   Sessions' } },
        { type = 'files', header = { '   MRU' } },
        { type = 'dir', header = { '   MRU ' .. vim.fn.getcwd() } },
        { type = 'bookmarks', header = { '   Bookmarks' } },
        { type = 'commands', header = { '   Commands' } },
      }
    end,
  },
  {
    'tpope/vim-vinegar',
  },
  {
    {
      'akinsho/toggleterm.nvim',
      version = '*',
      opts = {
        open_mapping = '<F12>',
        direction = 'vertical',
        size = 180,
      },
      init = function()
        -- Jenkins commands using Toggleterm.

        -- Set up a custom terminal for background tasks
        local Terminal = require('toggleterm.terminal').Terminal
        vim.g.jenkins_is_running = false

        local on_exit = function(_, code, _)
          vim.g.jenkins_is_running = false

          local log_level = vim.log.levels.INFO
          local message = 'Jenkins job finished successfully'
          if code ~= 0 then -- Exit code 0 means success
            log_level = vim.log.levels.ERROR
            message = 'Error running Jenkins job'
          end

          vim.notify(message, log_level, { title = 'Jenkins' })
        end

        -- Function to create a new terminal.
        local make_term = function()
          local term = Terminal:new {
            hidden = true,
            close_on_exit = false,
            on_exit = on_exit,
            direction = 'vertical',
          }
          term:open(180, 'vertical')
          term:close()
          return term
        end

        local term = make_term()

        vim.keymap.set('n', '<leader>cjt', function()
          term:toggle()
        end)

        -- The Jenkins deploy-branch command.
        vim.keymap.set('n', '<leader>cjd', function()
          if not vim.g.jenkins_is_running then
            vim.g.jenkins_is_running = true
            vim.notify('Deploying branch', vim.log.levels.INFO, { title = 'Jenkins' })
            term = make_term()
            term:send 'direnv reload; jenkins deploy-branch; exit'
          else
            term:toggle()
          end
        end)
      end,
    },
  },
  -- Undo tree
  {
    'debugloop/telescope-undo.nvim',
    dependencies = { -- note how they're inverted to above example
      {
        'nvim-telescope/telescope.nvim',
        dependencies = { 'nvim-lua/plenary.nvim' },
      },
    },
    keys = {
      { -- lazy style key map
        '<leader>u',
        '<cmd>Telescope undo<cr>',
        desc = 'undo history',
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
    keys = {
      {
        '<leader>un',
        function()
          require('notify').dismiss { silent = true, pending = true }
        end,
        desc = 'Dismiss all Notifications',
      },
    },
    opts = {
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
    },
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
      { "<leader>snh", function() require("noice").cmd("history") end, desc = "Noice History" },
      { "<leader>sna", function() require("noice").cmd("all") end, desc = "Noice All" },
      { "<leader>snd", function() require("noice").cmd("dismiss") end, desc = "Dismiss All" },
      { "<c-f>", function() if not require("noice.lsp").scroll(4) then return "<c-f>" end end, silent = true, expr = true, desc = "Scroll forward", mode = {"i", "n", "s"} },
      { "<c-b>", function() if not require("noice.lsp").scroll(-4) then return "<c-b>" end end, silent = true, expr = true, desc = "Scroll backward", mode = {"i", "n", "s"}},
    },
  },
  {
    'windwp/nvim-autopairs',
    -- Optional dependency
    dependencies = { 'hrsh7th/nvim-cmp' },
    config = function()
      require('nvim-autopairs').setup {}
      -- If you want to automatically add `(` after selecting a function or method
      local cmp_autopairs = require 'nvim-autopairs.completion.cmp'
      local cmp = require 'cmp'
      cmp.event:on('confirm_done', cmp_autopairs.on_confirm_done())
    end,
  },
  {
    'KenN7/vim-arsync',
    dependencies = 'prabirshrestha/async.vim',
  },
}
