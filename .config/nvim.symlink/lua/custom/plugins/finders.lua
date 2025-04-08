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
      local telescope = require 'telescope'
      local fzf_opts = {
        fuzzy = true, -- false will only do exact matching
        override_generic_sorter = true, -- override the generic sorter
        override_file_sorter = true, -- override the file sorter
        case_mode = 'smart_case', -- or "ignore_case" or "respect_case"
        -- the default case_mode is "smart_case"
      }
      telescope.setup {
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
          lsp_references = {
            fname_width = 65,
          },
          lsp_dynamic_workspace_symbols = {
            fname_width = 65,
            sorter = telescope.extensions.fzf.native_fzf_sorter(fzf_opts),
          },
        },
        extensions = {
          ['ui-select'] = {
            require('telescope.themes').get_dropdown(),
          },
          fzf = fzf_opts,
        },
      }
      -- Enable telescope extensions, if they are installed
      pcall(require('telescope').load_extension, 'fzf')
      pcall(require('telescope').load_extension, 'ui-select')
      pcall(require('telescope').load_extension, 'emoji')

      -- See `:help telescope.builtin`
      local builtin = require 'telescope.builtin'
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
        width = 0.60,
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
        -- If branch starts with a '*', remove it
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
            ['--preview-window'] = 'border-none,top,75%',
            ['--border-label'] = 'ctrl-r: toggle remote | ctrl-e: delete | ctrl-w: web',
            ['--border-label-pos'] = '5:bottom',
            ['--border'] = 'rounded',
          },
          winopts = {
            width = 175,
          },
          actions = {
            ['default'] = {
              function(selected)
                local branch, is_current = extract_branch(selected)
                -- If we are trying to switch to a remote branch, remove the 'origin/' prefix.
                if string.sub(branch, 1, 7) == 'origin/' then
                  branch = string.sub(branch, 8)
                end
                if not is_current then
                  vim.cmd('Git switch ' .. branch)
                end
              end,
              fzflua.actions.resume,
            },
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
            ['ctrl-r'] = {
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
            ['ctrl-w'] = {
              function(selected)
                local branch, _ = extract_branch(selected)
                vim.cmd(string.format('!gh pr view --web %s', branch))
                -- Check if the previous command failed
                if vim.v.shell_error ~= 0 then
                  vim.cmd '!gh browse'
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

              -- If we are trying to show details of a remote branch, remove the 'origin/' prefix.
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
      end, { desc = 'Git: switch branch', silent = true })

      -- Show Jira issues.

      local function show_jira_issues(args)
        local Terminal = require('toggleterm.terminal').Terminal

        local cmd = string.format('jira issues %s', args or '')

        fzflua.fzf_exec(cmd, {
          fzf_opts = {
            ['--header-lines'] = '1',
            ['--preview-window'] = 'border-none,top,50%',
            ['--scheme'] = 'history',
            ['--border-label'] = 'ctrl-t: transition | ctrl-i: new | ctrl-w: epics only | ctrl-h: all | ctrl-l: in epic | ctrl-u: update',
            ['--border-label-pos'] = '5:bottom',
            ['--border'] = 'rounded',
          },
          winopts = {
            width = 200,
          },
          actions = {
            ['ctrl-t'] = function(selected)
              local key = vim.split(selected[1], ' ', { trimempty = true })[1]
              Terminal:new({
                direction = 'float',
                cmd = string.format('jira transition %s', key),
                hidden = false,
                float_opts = { width = 60, height = 30 },
                on_close = fzflua.actions.resume,
              }):open()
            end,
            ['ctrl-i'] = function()
              Terminal:new({
                direction = 'float',
                cmd = 'jira create',
                hidden = false,
                float_opts = { width = 200, height = 50 },
                on_close = fzflua.actions.resume,
              }):open()
            end,
            ['enter'] = function(selected)
              -- Store `selected` in the system clipboard
              local key = vim.split(selected[1], ' ', { trimempty = true })[1]
              vim.fn.setreg('+', key)
            end,
            ['ctrl-e'] = {
              function(_)
                show_jira_issues ' --epics-only'
              end,
              fzflua.actions.resume,
            },
            ['ctrl-h'] = {
              function(_)
                show_jira_issues()
              end,
              fzflua.actions.resume,
            },
            ['ctrl-l'] = {
              function(selected)
                local key = vim.split(selected[1], ' ', { trimempty = true })[1]
                show_jira_issues(string.format(' --in-epic %s', key))
              end,
              fzflua.actions.resume,
            },
            ['ctrl-u'] = function(selected)
              local key = vim.split(selected[1], ' ', { trimempty = true })[1]
              Terminal:new({
                direction = 'float',
                cmd = string.format('jira update %s', key),
                hidden = false,
                float_opts = { width = 200, height = 50 },
                on_close = fzflua.actions.resume,
              }):open()
            end,
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
        '<leader>sJ',
        show_jira_issues,
        { desc = 'Search all Jira tickets', silent = true }
      )
      vim.keymap.set('n', '<leader>sj', function()
        show_jira_issues '--mine --current-sprint'
      end, { desc = 'Search my Jira tickets', silent = true })

      -- Show pip list
      local function pip_list()
        fzflua.fzf_exec('pip list --disable-pip-version-check', {
          fzf_opts = {
            ['--header-lines'] = '2',
          },
          winopts = {
            width = 100,
          },
        })
      end
      vim.keymap.set(
        'n',
        '<leader>sp',
        pip_list,
        { desc = 'Search python packages', silent = true }
      )
    end,
  },
}
