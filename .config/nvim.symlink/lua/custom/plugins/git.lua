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
        require('which-key').add {
          { '<leader>gu', group = 'Diff h[u]nk' },
        }
        map('n', '<leader>ga', gs.stage_hunk, { desc = 'GitSigns: [a]dd (stage) hunk' })
        map('v', '<leader>ga', function()
          gs.stage_hunk { vim.fn.line '.', vim.fn.line 'v' }
        end, { desc = 'GitSigns: [a]dd (stage) hunk' })
        map('n', '<leader>gx', gs.reset_hunk, { desc = 'GitSigns: reset hunk' })
        map('v', '<leader>gx', function()
          gs.reset_hunk { vim.fn.line '.', vim.fn.line 'v' }
        end, { desc = 'GitSigns: reset hunk' })
        map(
          'n',
          '<leader>gA',
          gs.stage_buffer,
          { desc = 'GitSigns: [A]dd (stage) buffer' }
        )
        map(
          'n',
          '<leader>gn',
          gs.undo_stage_hunk,
          { desc = 'GitSigns: u[n]do stage hunk' }
        )
        map('n', '<leader>gX', gs.reset_buffer, { desc = 'GitSigns: reset buffer' })
        map('n', '<leader>gv', gs.preview_hunk, { desc = 'GitSigns: [v]iew hunk' })
        map('n', '<leader>gn', function()
          gs.blame_line { full = true }
        end, { desc = 'GitSigns: blame line' })
        map(
          'n',
          '<leader>gt',
          gs.toggle_current_line_blame,
          { desc = 'GitSigns: [t]oggle line blame' }
        )
        -- map('n', '<leader>gud', gs.diffthis, { desc = 'GitSigns: [d]iff this' })
        -- map('n', '<leader>guD', function()
        --   gs.diffthis '~'
        -- end, { desc = 'GitSigns: [D]iff this (cached)' })
        map(
          'n',
          '<leader>gT',
          gs.toggle_deleted,
          { desc = 'GitSigns: [T]oggle deleted signs' }
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
        end, { desc = 'GitSigns: toggle base index|master' })
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
        desc = 'Flog: show git [l]og',
      },
      {
        '<leader>gL',
        ':Flog -path=%<CR>',
        desc = 'Flog: show git [L]og of current file',
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
        autocmd User FugitiveCommit set foldmethod=syntax foldenable
      ]]
    end,
    keys = {
      -- {
      --   '<leader>gs',
      --   ':Gtabedit :<CR>:set previewwindow <CR>',
      --   desc = 'Fugitive: git [s]tatus',
      -- },
      {
        '<leader>gc',
        ':vertical rightb :Git commit<CR>',
        desc = 'Fugitive: git [c]ommit',
      },
      {
        '<leader>gp',
        ':Git push',
        desc = 'Fugitive: git [p]ush',
      },
      {
        '<leader>gr',
        ':Git rebase -i master<CR>',
        desc = 'Fugitive: git [r]ebase -i master',
      },
      {
        '<leader>gb',
        ':Git blame<CR>',
        desc = 'Fugitive: git [b]lame',
      },
    },
    init = function()
      local wk = require 'which-key'
      wk.add {
        { '<leader>g', group = '[g]it' },
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
  --       ['<leader>gh'] = 'Git-Line: Copy [g]it [l]ine to clipboard',
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
        desc = 'GitLinker: [y]ank GitHub URL',
        mode = 'n',
      },
      {
        '<leader>gy',
        function()
          require('gitlinker').get_buf_range_url 'v'
        end,
        desc = 'GitLinker: [y]ank GitHub URL',
        mode = 'v',
      },
    },
  },
  {
    'sindrets/diffview.nvim',
    cmd = {
      'DiffviewOpen',
      'DiffviewToggleFiles',
      'DiffviewFocusFiles',
      'DiffviewFileHistory',
    },
    keys = {
      {
        '<leader>gm',
        ':DiffviewOpen master<CR>',
        desc = 'Diffview: diff [m]aster',
      },
      {
        '<leader>gh',
        ':DiffviewFileHistory %<CR>',
        desc = 'Diffview: view current file [h]istory',
        mode = { 'n', 'v' },
      },
      {
        '<leader>gs',
        ':DiffviewOpen<CR>',
        desc = 'Diffview: git status',
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
          approve_review = { lhs = '<C-A>', desc = 'approve review' },
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
          -- submit_review = { lhs = '<leader>vs', desc = 'submit review' },
          -- discard_review = { lhs = '<leader>vd', desc = 'discard review' },
          next_entry = { lhs = 'j', desc = 'move to next changed file' },
          prev_entry = { lhs = 'k', desc = 'move to previous changed file' },
          select_entry = { lhs = '<cr>', desc = 'show selected changed file diffs' },
          refresh_files = { lhs = 'R', desc = 'refresh changed files panel' },
          select_next_entry = { lhs = ']q', desc = 'move to next changed file' },
          select_prev_entry = { lhs = '[q', desc = 'move to previous changed file' },
          select_first_entry = { lhs = '[Q', desc = 'move to first changed file' },
          select_last_entry = { lhs = ']Q', desc = 'move to last changed file' },
          close_review_tab = { lhs = '<C-c>', desc = 'close review tab' },
          toggle_viewed = { lhs = '<leader><space>', desc = 'toggle viewer viewed state' },
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
        { desc = 'Octo: open PR list' }
      )
    end,
  },
}
