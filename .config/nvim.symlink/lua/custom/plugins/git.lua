return {
  -- Adds git related signs to the gutter, as well as utilities for managing changes
  -- See `:help gitsigns` to understand what the configuration keys do
  {
    'lewis6991/gitsigns.nvim',
    opts = {
      signs = {
        add = { text = '+' },
        change = { text = '~' },
        delete = { text = '_' },
        topdelete = { text = '‾' },
        changedelete = { text = '~' },
        untracked = { text = '┆' },
      },
      on_attach = function(bufnr)
        local gs = package.loaded.gitsigns

        local function map(mode, l, r, opts)
          opts = opts or {}
          opts.buffer = bufnr
          vim.keymap.set(mode, l, r, opts)
        end

        -- Navigation
        map('n', ']c', function()
          if vim.wo.diff then
            return ']c'
          end
          vim.schedule(function()
            gs.next_hunk()
          end)
          return '<Ignore>'
        end, { expr = true, desc = 'GitSigns: Next [c]hange' })

        map('n', '[c', function()
          if vim.wo.diff then
            return '[c'
          end
          vim.schedule(function()
            gs.prev_hunk()
          end)
          return '<Ignore>'
        end, { expr = true, desc = 'GitSigns: Previous [c]hange' })

        -- Actions
        -- Document key chains
        require('which-key').register {
          ['<leader>ch'] = { name = 'diff [h]unk', _ = 'which_key_ignore' },
        }
        map('n', '<leader>chs', gs.stage_hunk, { desc = 'GitSigns: [s]tage hunk' })
        map('n', '<leader>chr', gs.reset_hunk, { desc = 'GitSigns: [r]eset hunk' })
        map('v', '<leader>chs', function()
          gs.stage_hunk { vim.fn.line '.', vim.fn.line 'v' }
        end, { desc = 'GitSigns: [s]tage hunk' })
        map('v', '<leader>chr', function()
          gs.reset_hunk { vim.fn.line '.', vim.fn.line 'v' }
        end, { desc = 'GitSigns: [r]eset hunk' })
        map('n', '<leader>chS', gs.stage_buffer, { desc = 'GitSigns: [S]tage buffer' })
        map(
          'n',
          '<leader>chu',
          gs.undo_stage_hunk,
          { desc = 'GitSigns: [u]ndo stage hunk' }
        )
        map('n', '<leader>chR', gs.reset_buffer, { desc = 'GitSigns: [R]eset buffer' })
        map('n', '<leader>chp', gs.preview_hunk, { desc = 'GitSigns: [p]review hunk' })
        map('n', '<leader>chl', function()
          gs.blame_line { full = true }
        end, { desc = 'GitSigns: b[l]ame line' })
        map(
          'n',
          '<leader>chb',
          gs.toggle_current_line_blame,
          { desc = 'GitSigns: Toggle line [b]lame' }
        )
        -- map('n', '<leader>chd', gs.diffthis, { desc = 'GitSigns: [d]iff this' })
        -- map('n', '<leader>chD', function()
        --   gs.diffthis '~'
        -- end, { desc = 'GitSigns: [D]iff this (cached)' })
        map(
          'n',
          '<leader>chd',
          gs.toggle_deleted,
          { desc = 'GitSigns: Toggle [d]eleted signs' }
        )

        -- Text object
        map({ 'o', 'x' }, 'ih', ':<C-U>Gitsigns select_hunk<CR>')
      end,
    },
  },
  -- Flog is a fast, beautiful, and powerful git branch viewer for Vim.
  {
    'rbong/vim-flog',
    lazy = true,
    cmd = { 'Flog', 'Flogsplit', 'Floggit' },
    keys = {
      {
        '<leader>gl',
        ':Flog<CR>',
        desc = 'Flog: show [g]it [l]og',
      },
    },
  },
  -- Fugitive is the premier Vim plugin for Git. Or maybe it's the premier Git
  -- plugin for Vim? Either way, it's "so awesome, it should be illegal".
  -- That's why it's called Fugitive.
  {
    'tpope/vim-fugitive',
    lazy = false,
    config = function()
      -- Restore folds in fugitive commit windows. See this issue about
      -- future development:
      -- https://github.com/tpope/vim-fugitive/issues/1735#issuecomment-822037483
      vim.cmd [[
        autocmd User FugitiveCommit set foldmethod=syntax
      ]]
    end,
    keys = {
      {
        '<leader>gs',
        ':Gtabedit :<CR>:set previewwindow <CR>',
        desc = 'Git: [g]it [s]tatus',
      },
      {
        '<leader>gc',
        ':Git commit<CR>',
        desc = 'Git: [g]it [c]ommit',
      },
      {
        '<leader>gp',
        ':Git push',
        desc = 'Git: [g]it [p]ush',
      },
      {
        '<leader>gr',
        ':Git rebase -i master<CR>',
        desc = 'Git: [g]it [r]ebase -i master',
      },
      {
        '<leader>gb',
        ':Git blame<CR>',
        desc = 'Git: [g]it [b]lame',
      },
    },
    init = function()
      require('which-key').register {
        ['<leader>g'] = { name = '[G]it', _ = 'which_key_ignore' },
      }
    end,
  },
  {
    'ruanyl/vim-gh-line',
    init = function()
      -- Set the command to copy the line to the clipboard, instead of opening in the
      -- browser.
      vim.g.gh_open_command = 'fn() { echo "$@" | xclip -selection c -r; }; fn '
      vim.g.gh_line_map_default = 0
      vim.g.gh_line_blame_map_default = 0
      vim.g.gh_line_map = '<leader>gh'
      require('which-key').register {
        ['<leader>gh'] = 'Git-Line: Copy [g]it [l]ine to clipboard',
      }
    end,
  },
}
