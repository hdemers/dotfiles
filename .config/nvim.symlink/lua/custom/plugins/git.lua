return {
  -- Adds git related signs to the gutter, as well as utilities for managing changes
  -- See `:help gitsigns` to understand what the configuration keys do
  {
    'lewis6991/gitsigns.nvim',
    opts = {
      signs = {
        add = { text = '│' },
        change = { text = '│' },
      },
      on_attach = function(bufnr)
        local gs = package.loaded.gitsigns
        local base = 'HEAD'

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
        end, { expr = true, desc = 'Gitsigns: next change' })

        map('n', '[c', function()
          if vim.wo.diff then
            return '[c'
          end
          vim.schedule(function()
            gs.prev_hunk()
          end)
          return '<Ignore>'
        end, { expr = true, desc = 'Gitsigns: previous change' })

        -- Actions
        -- Document key chains
        require('which-key').add {
          { '<leader>gu', group = 'Diff hunk' },
        }
        map('n', '<leader>ga', gs.stage_hunk, { desc = 'Gitsigns: add (stage) hunk' })
        map('v', '<leader>ga', function()
          gs.stage_hunk { vim.fn.line '.', vim.fn.line 'v' }
        end, { desc = 'Gitsigns: add (stage) hunk' })
        map('n', '<leader>gx', gs.reset_hunk, { desc = 'Gitsigns: reset hunk' })
        map('v', '<leader>gx', function()
          gs.reset_hunk { vim.fn.line '.', vim.fn.line 'v' }
        end, { desc = 'Gitsigns: reset hunk' })
        map('n', '<leader>gA', gs.stage_buffer, { desc = 'Gitsigns: add (stage) buffer' })
        map('n', '<leader>gn', gs.undo_stage_hunk, { desc = 'Gitsigns: undo stage hunk' })
        map('n', '<leader>gX', gs.reset_buffer, { desc = 'Gitsigns: reset buffer' })
        map('n', '<leader>gv', gs.preview_hunk, { desc = 'Gitsigns: view hunk' })
        map('n', '<leader>gn', function()
          gs.blame_line { full = true }
        end, { desc = 'Gitsigns: blame line' })
        map(
          'n',
          '<leader>gt',
          gs.toggle_current_line_blame,
          { desc = 'Gitsigns: toggle line blame' }
        )
        -- map('n', '<leader>gud', gs.diffthis, { desc = 'Gitsigns: diff this' })
        -- map('n', '<leader>guD', function()
        --   gs.diffthis '~'
        -- end, { desc = 'Gitsigns: diff this (cached)' })
        map(
          'n',
          '<leader>gT',
          gs.toggle_deleted,
          { desc = 'Gitsigns: toggle deleted signs' }
        )

        -- Text object
        map({ 'o', 'x' }, 'ih', ':<C-U>Gitsigns select_hunk<CR>')

        -- Toggle base between HEAD and master
        map('n', '<leader>gi', function()
          if base == 'HEAD' then
            gs.change_base 'master'
            vim.notify('Gitsign base changed to master', 'info')
            base = 'master'
          else
            gs.change_base 'HEAD'
            vim.notify('Gitsign base changed to HEAD', 'info')
            base = 'HEAD'
          end
        end, { desc = 'Gitsigns: toggle base index|master' })
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
        desc = 'Flog: show git log',
      },
      -- {
      --   '<leader>gL',
      --   ':Flog -path=%<CR>',
      --   desc = 'Flog: show git log of current file',
      -- },
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
        autocmd User FugitiveCommit set foldmethod=syntax foldenable
      ]]
    end,
    keys = {
      -- {
      --   '<leader>gs',
      --   ':Gtabedit :<CR>:set previewwindow <CR>',
      --   desc = 'Fugitive: git status',
      -- },
      {
        '<leader>gc',
        ':vertical rightb :Git commit<CR>',
        desc = 'Fugitive: git commit',
      },
      {
        '<leader>gp',
        ':Git push',
        desc = 'Fugitive: git push',
      },
      {
        '<leader>gr',
        ':Git rebase -i master<CR>',
        desc = 'Fugitive: git rebase -i master',
      },
      {
        '<leader>gb',
        ':Git blame<CR>',
        desc = 'Fugitive: git blame',
      },
    },
    init = function()
      local wk = require 'which-key'
      wk.add {
        { '<leader>g', group = 'Git' },
      }
    end,
  },
  -- {
  --   'ruanyl/vim-gh-line',
  --   init = function()
  --     -- Set the command to copy the line to the clipboard, instead of opening in the
  --     -- browser.
  --     vim.g.gh_open_command = 'fn() { echo "$@" | xclip -selection c -r; }; fn '
  --     vim.g.gh_line_map_default = 0
  --     vim.g.gh_line_blame_map_default = 0
  --     vim.g.gh_line_map = '<leader>gh'
  --     require('which-key').register {
  --       ['<leader>gh'] = 'Git-Line: Copy git line to clipboard',
  --     }
  --   end,
  -- },
  {
    'ruifm/gitlinker.nvim',
    dependencies = { 'nvim-lua/plenary.nvim' },
    config = function()
      require('gitlinker').setup {
        mappings = nil,
      }
    end,
    keys = {
      {
        '<leader>gy',
        function()
          require('gitlinker').get_buf_range_url 'n'
        end,
        desc = 'Gitlinker: yank github url',
        mode = 'n',
      },
      {
        '<leader>gy',
        function()
          require('gitlinker').get_buf_range_url 'v'
        end,
        desc = 'Gitlinker: yank github url',
        mode = 'v',
      },
    },
  },
  {
    'sindrets/diffview.nvim',
    keys = {
      {
        '<leader>gm',
        ':DiffviewOpen master<CR>',
        desc = 'Diffview: diff master',
      },
      {
        '<leader>gh',
        ':DiffviewFileHistory %<CR>',
        desc = 'Diffview: view current file history',
        mode = { 'n', 'v' },
      },
      {
        '<leader>gs',
        ':DiffviewOpen<CR>',
        desc = 'Diffview: git status',
      },
      {
        '<leader>gL',
        ':DiffviewFileHistory<CR>',
        desc = 'Diffview: all history',
      },
    },
    opts = {
      file_panel = {
        listing_style = 'list',
        win_config = {
          width = 55,
        },
      },
    },
    config = function(_, opts)
      require('diffview').setup(opts)
    end,
  },
  {
    'pwntester/octo.nvim',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-telescope/telescope.nvim',
      'nvim-tree/nvim-web-devicons',
    },
    opts = {
      mappings_disable_default = true,
      mappings = {
        submit_win = {
          approve_review = { lhs = '<C-A>', desc = 'Approve review' },
        },
        review_diff = {
          add_review_comment = { lhs = '<localleader>cc', desc = 'Octo: add comment' },
          add_review_suggestion = {
            lhs = '<localleader>cs',
            desc = 'Octo: add suggestion',
          },
          next_thread = { lhs = ']t', desc = 'Octo: move to next thread' },
          prev_thread = { lhs = '[t', desc = 'Octo: move to previous thread' },
          select_next_entry = { lhs = ']q', desc = 'Octo: move to next changed file' },
          select_prev_entry = { lhs = '[q', desc = 'Octo: move to previous changed file' },
          select_first_entry = { lhs = '[Q', desc = 'Octo: move to first changed file' },
          select_last_entry = { lhs = ']Q', desc = 'Octo: move to last changed file' },
          toggle_viewed = { lhs = '<localleader>cv', desc = 'Octo: toggle viewed' },
        },
        review_thread = {
          add_comment = { lhs = '<space>cc', desc = 'Octo: add comment' },
        },
        file_panel = {
          -- submit_review = { lhs = '<leader>vs', desc = 'Submit review' },
          -- discard_review = { lhs = '<leader>vd', desc = 'Discard review' },
          next_entry = { lhs = 'j', desc = 'Move to next changed file' },
          prev_entry = { lhs = 'k', desc = 'Move to previous changed file' },
          select_entry = { lhs = '<cr>', desc = 'Show selected changed file diffs' },
          refresh_files = { lhs = 'R', desc = 'Refresh changed files panel' },
          select_next_entry = { lhs = ']q', desc = 'Move to next changed file' },
          select_prev_entry = { lhs = '[q', desc = 'Move to previous changed file' },
          select_first_entry = { lhs = '[Q', desc = 'Move to first changed file' },
          select_last_entry = { lhs = ']Q', desc = 'Move to last changed file' },
          close_review_tab = { lhs = '<C-c>', desc = 'Close review tab' },
          toggle_viewed = { lhs = '<leader><space>', desc = 'Toggle viewer viewed state' },
        },
      },
      suppress_missing_scope = {
        projects_v2 = true,
      },
    },
    config = function(_, opts)
      require('octo').setup(opts)

      -- Add keybinding for Octo pr list
      vim.keymap.set(
        'n',
        '<leader>so',
        ':Octo pr list<CR>',
        { desc = 'Octo: open pr list' }
      )
    end,
  },
  {
    'isakbm/gitgraph.nvim',
    enabled = false,
    opts = {
      symbols = {
        merge_commit = '',
        commit = '○',
        merge_commit_end = '',
        commit_end = '',
      },
      format = {
        timestamp = '%H:%M:%S %d-%m-%Y',
        fields = { 'hash', 'timestamp', 'author', 'branch_name', 'tag' },
      },
      hooks = {
        -- Check diff of a commit
        on_select_commit = function(commit)
          vim.notify('DiffviewOpen ' .. commit.hash .. '^!')
          vim.cmd(':DiffviewOpen ' .. commit.hash .. '^!')
        end,
        -- Check diff from commit a -> commit b
        on_select_range_commit = function(from, to)
          vim.notify('DiffviewOpen ' .. from.hash .. '~1..' .. to.hash)
          vim.cmd(':DiffviewOpen ' .. from.hash .. '~1..' .. to.hash)
        end,
      },
    },
    keys = {
      {
        '<leader>gL',
        function()
          require('gitgraph').draw({}, { all = true, max_count = 5000 })
        end,
        desc = 'GitGraph',
      },
    },
  },
}
