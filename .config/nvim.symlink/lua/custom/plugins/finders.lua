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
      { 'xiyaowong/telescope-emoji.nvim' },
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
            width = 0.7,
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
          colorscheme = {
            enable_preview = true,
          },
        },
        extensions = {
          ['ui-select'] = {
            require('telescope.themes').get_dropdown(),
          },
          -- fzf = {
          --   fuzzy = true, -- false will only do exact matching
          --   override_generic_sorter = true,
          --   override_file_sorter = true,
          -- },
        },
      }
      -- Enable telescope extensions, if they are installed
      pcall(require('telescope').load_extension, 'fzf')
      pcall(require('telescope').load_extension, 'ui-select')
      pcall(require('telescope').load_extension, 'emoji')

      -- See `:help telescope.builtin`
      local builtin = require 'telescope.builtin'

      vim.keymap.set('n', '<leader>sh', builtin.help_tags, { desc = 'search [h]elp' })
      vim.keymap.set('n', '<leader>sk', builtin.keymaps, { desc = 'search [k]eymaps' })
      vim.keymap.set('n', '<leader>sf', function()
        builtin.find_files { hidden = true }
      end, { desc = 'search [f]iles' })
      vim.keymap.set(
        'n',
        '<leader>ss',
        builtin.builtin,
        { desc = 'search [s]elect Telescope' }
      )
      vim.keymap.set(
        'n',
        '<leader>sw',
        builtin.grep_string,
        { desc = 'search current [w]ord' }
      )
      vim.keymap.set('n', '<leader>sg', builtin.live_grep, { desc = 'search by [g]rep' })
      vim.keymap.set(
        'n',
        '<leader>sd',
        builtin.diagnostics,
        { desc = 'search [d]iagnostics' }
      )
      vim.keymap.set('n', '<leader>sr', builtin.resume, { desc = 'search [r]esume' })
      vim.keymap.set(
        'n',
        '<leader>s.',
        builtin.oldfiles,
        { desc = 'search recent files ("." for repeat)' }
      )
      vim.keymap.set(
        'n',
        '<leader>si',
        builtin.git_files,
        { desc = 'search g[i]t files' }
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
      end, { desc = 'search [/] in Open Files' })

      -- Shortcut for searching your neovim configuration files
      vim.keymap.set('n', '<leader>sc', function()
        builtin.find_files { cwd = vim.fn.stdpath 'config' }
      end, { desc = 'search neovim [c]onfig files' })
    end,
    init = function()
      -- The following adds a space between Telescope's file iconn and the filename.
      -- This is really only needed when using the Sudo font. For some reason, the
      -- glyph from that font are not spaced correctly.
      local devicons = require 'nvim-web-devicons'
      local original_get_icon = devicons.get_icon
      devicons.get_icon = function(filename, extension, is_directory)
        local icon, icon_highlight = original_get_icon(filename, extension, is_directory)
        if icon ~= nil then
          icon = icon .. ' '
        end
        return icon, icon_highlight
      end
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
        border = false,
      },
    },
    init = function()
      local fzflua = require 'fzf-lua'

      -- Show git branches and allow switching between them.

      local function extract_branch(items)
        local splitted = vim.split(items[1], ' ', { trimempty = true })
        local metadata = {}
        for k, v in pairs(splitted) do
          if v ~= nil and v ~= '' then
            metadata[k] = v
          end
        end
        local branch = metadata[1]
        local is_current = false
        -- If branch starts with a '*',remote it
        if string.sub(branch, 1, 1) == '*' then
          branch = string.sub(branch, 2)
          is_current = true
        end
        return branch, is_current
      end

      -- Toggle flag indicating if we are currently showing all branches.
      local is_git_showing_all_branches = false

      local function show_git_branch(all)
        -- Reset the toggle flag.
        is_git_showing_all_branches = false

        local contents = 'git rb'
        if all then
          contents = 'git rba'
        end

        fzflua.fzf_exec(contents, {
          fzf_opts = {
            ['--header-lines'] = '1',
            ['--preview-window'] = 'top,75%',
          },
          winopts = {
            win_width = 175,
          },
          actions = {
            ['default'] = function(selected)
              local branch, is_current = extract_branch(selected)
              if not is_current then
                vim.cmd('Git switch ' .. branch)
              end
            end,
            ['ctrl-e'] = {
              function(selected)
                local branch, is_current = extract_branch(selected)
                if is_current then
                  vim.notify('Cannot delete current branch', vim.log.levels.WARN)
                else
                  -- Get confirmation from the user
                  local confirm = vim.fn.input(
                    'Confirm deletion',
                    'Delete branch ' .. branch .. '? [y/N] '
                  )
                  if confirm:sub(-1) == 'y' then
                    vim.cmd('Git branch -D ' .. branch)
                  end
                end
              end,
              fzflua.actions.resume,
            },
            ['ctrl-o'] = {
              function(_)
                if is_git_showing_all_branches then
                  show_git_branch(false)
                  is_git_showing_all_branches = false
                else
                  show_git_branch(true)
                  is_git_showing_all_branches = true
                end
              end,
              fzflua.actions.resume,
            },
          },
          preview = {
            type = 'cmd',
            fn = function(items)
              -- Split items[1] by space and select the first one
              local branch, _ = extract_branch(items)

              local remote_branch = branch
              if string.sub(branch, 1, 7) == 'origin/' then
                remote_branch = string.sub(branch, 8)
              end
              return string.format(
                'env GH_FORCE_TTY=100 gh pr view --comments %s || git show --stat --color=always %s',
                remote_branch,
                branch
              )
            end,
          },
        })
      end
      vim.keymap.set('n', '<leader>gw', function()
        show_git_branch(false)
      end, { desc = 'Git: s[w]itch branch', silent = true })

      -- Show Jira issues.

      local function show_jira_issues()
        fzflua.fzf_exec('jira issues -p ELMO', {
          fzf_opts = {
            ['--header-lines'] = '2',
            ['--preview-window'] = 'top,50%',
          },
          winopts = {
            win_width = 200,
          },
          preview = {
            type = 'cmd',
            fn = function(items)
              -- Split items[1] by space and select the first one
              local key = vim.split(items[1], ' ', { trimempty = true })[1]
              return string.format('jira describe %s', key)
            end,
          },
        })
      end
      vim.keymap.set(
        'n',
        '<leader>sj',
        show_jira_issues,
        { desc = 'Jira: search [j]ira', silent = true }
      )

      -- pip list
      local function pip_list()
        fzflua.fzf_exec('pip list --disable-pip-version-check', {
          fzf_opts = {
            ['--header-lines'] = '2',
          },
          winopts = {
            win_width = 70,
          },
        })
      end
      vim.keymap.set(
        'n',
        '<leader>sp',
        pip_list,
        { desc = 'Pip: search [p]ip', silent = true }
      )
    end,
  },
}
