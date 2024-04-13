return {
  { -- Fuzzy Finder (files, lsp, etc)
    'nvim-telescope/telescope.nvim',
    event = 'VimEnter',
    branch = '0.1.x',
    dependencies = {
      'nvim-lua/plenary.nvim',
      { -- If encountering errors, see telescope-fzf-native README for install instructions
        'nvim-telescope/telescope-fzf-native.nvim',

        -- `build` is used to run some command when the plugin is installed/updated.
        -- This is only run then, not every time Neovim starts up.
        build = 'make',

        -- `cond` is a condition used to determine whether this plugin should be
        -- installed and loaded.
        cond = function()
          return vim.fn.executable 'make' == 1
        end,
      },
      { 'nvim-telescope/telescope-ui-select.nvim' },

      -- Useful for getting pretty icons, but requires a Nerd Font.
      { 'nvim-tree/nvim-web-devicons', enabled = vim.g.have_nerd_font },
    },
    config = function()
      -- Telescope is a fuzzy finder that comes with a lot of different things that
      -- it can fuzzy find! It's more than just a "file finder", it can search
      -- many different aspects of Neovim, your workspace, LSP, and more!
      --
      -- The easiest way to use telescope, is to start by doing something like:
      --  :Telescope help_tags
      --
      -- After running this command, a window will open up and you're able to
      -- type in the prompt window. You'll see a list of help_tags options and
      -- a corresponding preview of the help.
      --
      -- Two important keymaps to use while in telescope are:
      --  - Insert mode: <c-/>
      --  - Normal mode: ?
      --
      -- This opens a window that shows you all of the keymaps for the current
      -- telescope picker. This is really useful to discover what Telescope can
      -- do as well as how to actually do it!

      -- [[ Configure Telescope ]]
      -- See `:help telescope` and `:help telescope.setup()`
      require('telescope').setup {
        -- You can put your default mappings / updates / etc. in here
        --  All the info you're looking for is in `:help telescope.setup()`
        --
        defaults = {
          mappings = {
            i = { ['<c-enter>'] = 'to_fuzzy_refine' },
          },
          layout_config = {
            width = 0.6,
          },
        },
        pickers = {
          live_grep = {
            additional_args = function()
              return { '--hidden' }
            end,
          },
          grep_string = {
            additional_args = function()
              return { '--hidden' }
            end,
          },
          buffers = {
            mappings = {
              n = { ['x'] = 'delete_buffer' },
            },
          },
        },
        extensions = {
          ['ui-select'] = {
            require('telescope.themes').get_dropdown(),
          },
        },
      }
      -- Enable telescope extensions, if they are installed
      pcall(require('telescope').load_extension, 'fzf')
      pcall(require('telescope').load_extension, 'ui-select')

      -- See `:help telescope.builtin`
      local builtin = require 'telescope.builtin'
      vim.keymap.set('n', '<leader>sh', builtin.help_tags, { desc = '[S]earch [H]elp' })
      vim.keymap.set('n', '<leader>sk', builtin.keymaps, { desc = '[S]earch [K]eymaps' })
      vim.keymap.set('n', '<leader>sf', function()
        builtin.find_files { hidden = true }
      end, { desc = '[S]earch [F]iles' })
      vim.keymap.set(
        'n',
        '<leader>ss',
        builtin.builtin,
        { desc = '[S]earch [S]elect Telescope' }
      )
      vim.keymap.set(
        'n',
        '<leader>sw',
        builtin.grep_string,
        { desc = '[S]earch current [W]ord' }
      )
      vim.keymap.set(
        'n',
        '<leader>sg',
        builtin.live_grep,
        { desc = '[S]earch by [G]rep' }
      )
      vim.keymap.set(
        'n',
        '<leader>sd',
        builtin.diagnostics,
        { desc = '[S]earch [D]iagnostics' }
      )
      vim.keymap.set('n', '<leader>sr', builtin.resume, { desc = '[S]earch [R]esume' })
      vim.keymap.set(
        'n',
        '<leader>s.',
        builtin.oldfiles,
        { desc = '[S]earch Recent Files ("." for repeat)' }
      )
      vim.keymap.set(
        'n',
        '<leader>si',
        builtin.git_files,
        { desc = '[S]earch G[i]t Files' }
      )
      vim.keymap.set(
        'n',
        '<leader><leader>',
        builtin.buffers,
        { desc = '[ ] Find existing buffers' }
      )

      -- Slightly advanced example of overriding default behavior and theme
      -- You can pass additional configuration to telescope to change theme, layout, etc.
      vim.keymap.set('n', '<leader>/', function()
        builtin.current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
          previewer = false,
          layout_config = {
            width = 120,
            height = 0.5,
          },
        })
      end, { desc = '[/] Fuzzily search in current buffer' })

      -- Also possible to pass additional configuration options.
      --  See `:help telescope.builtin.live_grep()` for information about particular keys
      vim.keymap.set('n', '<leader>s/', function()
        builtin.live_grep {
          grep_open_files = true,
          prompt_title = 'Live Grep in Open Files',
        }
      end, { desc = '[S]earch [/] in Open Files' })

      -- Shortcut for searching your neovim configuration files
      vim.keymap.set('n', '<leader>sn', function()
        builtin.find_files { cwd = vim.fn.stdpath 'config' }
      end, { desc = '[S]earch [N]eovim files' })
    end,
  },
  {
    'ibhagwan/fzf-lua',
    -- optional for icon support
    dependencies = { 'nvim-tree/nvim-web-devicons', enabled = vim.g.have_nerd_font },
    opts = {
      grep = {
        rg_opts = '--hidden --column --line-number --no-heading --color=always --smart-case --max-columns=4096 -e',
      },
      winopts = {
        win_width = 0.60,
      },
    },
    keys = {
      -- {
      --   '<leader>sw',
      --   function()
      --     require('fzf-lua').grep_cword()
      --   end,
      --   desc = '[S]earch current [W]ord',
      -- },
      -- {
      --   '<leader>sg',
      --   function()
      --     require('fzf-lua').live_grep()
      --   end,
      --   desc = '[S]earch by [G]rep',
      -- },
      -- {
      --   '<leader>si',
      --   function()
      --     require('fzf-lua').git_files()
      --   end,
      --   desc = '[S]earch G[i]t Files',
      -- },
      -- {
      --   '<leader><leader>',
      --   function()
      --     require('fzf-lua').buffers()
      --   end,
      --   desc = '[ ] Find existing buffers',
      -- },
      -- {
      --   '<leader>/',
      --   function()
      --     require('fzf-lua').grep_curbuf()
      --   end,
      --   desc = '[/] Fuzzily search in current buffer',
      -- },
      -- {
      --   '<leader>sf',
      --   function()
      --     require('fzf-lua').files()
      --   end,
      --   desc = '[S]earch [F]iles',
      -- },
    },
  },
}
