-- ─────────────────────────────────────────────────────────────────────────────── --
-- [[ General Neovim Settings ]]

-- Set <space> as the leader key
-- See `:help mapleader`
--  NOTE: Must happen before plugins are loaded (otherwise wrong leader will be used)
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Set to true if you have a Nerd Font installed
vim.g.have_nerd_font = true

-- [[ Setting options ]]
-- See `:help vim.opt`
-- NOTE: You can change these options as you wish!
--  For more options, you can see `:help option-list`

-- Make line numbers default
vim.opt.number = false
-- You can also add relative line numbers, for help with jumping.
--  Experiment for yourself to see if you like it!
-- vim.opt.relativenumber = true

-- Enable mouse mode, can be useful for resizing splits for example!
vim.opt.mouse = 'a'

-- Don't show the mode, since it's already in status line
vim.opt.showmode = false

-- Sync clipboard between OS and Neovim.
--  Schedule the setting after `UiEnter` because it can increase startup-time.
--  Remove this option if you want your OS clipboard to remain independent.
--  See `:help 'clipboard'`
vim.schedule(function()
  vim.opt.clipboard = 'unnamedplus'
end)

-- Enable break indent
vim.opt.breakindent = true

-- Save undo history
vim.opt.undofile = true

-- Case-insensitive searching UNLESS \C or capital in search
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- Keep signcolumn on by default
vim.opt.signcolumn = 'yes'

-- Decrease update time
vim.opt.updatetime = 250

-- Decrease mapped sequence wait time
-- Displays which-key popup sooner
vim.opt.timeoutlen = 300

-- Configure how new splits should be opened
vim.opt.splitright = true
vim.opt.splitbelow = true

-- Sets how neovim will display certain whitespace in the editor.
--  See `:help 'list'`
--  and `:help 'listchars'`
vim.opt.list = true
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }

-- Preview substitutions live, as you type!
vim.opt.inccommand = 'split'

-- Show which line your cursor is on
vim.opt.cursorline = false

-- Minimal number of screen lines to keep above and below the cursor.
vim.opt.scrolloff = 10

-- Ensure we use guifg and guibg colors from color schemes
vim.opt.termguicolors = true

-- if performing an operation that would fail due to unsaved changes in the buffer (like `:q`),
-- instead raise a dialog asking if you wish to save the current file(s)
-- See `:help 'confirm'`
vim.opt.confirm = true

-- Treesitter-based folding.
-- Don't enable folding by default
vim.opt.foldenable = false
vim.opt.foldmethod = 'expr'
vim.opt.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
vim.opt.foldtext = ''
vim.opt.fillchars = {
  foldclose = '>',
  foldopen = '',
}

-- Sets the Python executable to be used by Neovim. This requires the existence
-- of a virtualenv named `nvim` with packages `pynvim` and `jupyter_client`
-- installed.
vim.g.python3_host_prog = vim.env.HOME .. '/.virtualenvs/nvim/bin/python'

-- ┌────────────────────────────────────────────────────────────────────────────
-- │ Keymaps

-- Clear highlight on search when pressing <Esc> in normal mode
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- Diagnostic keymaps
-- vim.keymap.set(
--   'n',
--   '[d',
--   vim.diagnostic.goto_prev,
--   { desc = 'Go to previous diagnostic message' }
-- )
-- vim.keymap.set(
--   'n',
--   ']d',
--   vim.diagnostic.goto_next,
--   { desc = 'Go to next diagnostic message' }
-- )
vim.keymap.set(
  'n',
  '<leader>e',
  vim.diagnostic.open_float,
  { desc = 'Diagnostic error messages' }
)
vim.keymap.set(
  'n',
  '<leader>l',
  vim.diagnostic.setloclist,
  { desc = 'Diagnostic quickfix list' }
)

-- Exit terminal mode in the builtin terminal with a shortcut that is a bit easier
-- for people to discover. Otherwise, you normally need to press <C-\><C-n>, which
-- is not what someone will guess without a bit more experience.
--
-- NOTE: This won't work in all terminal emulators/tmux/etc. Try your own mapping
-- or just use <C-\><C-n> to exit terminal mode
vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- TIP: Disable arrow keys in normal mode
-- vim.keymap.set('n', '<left>', '<cmd>echo "Use h to move!!"<CR>')
-- vim.keymap.set('n', '<right>', '<cmd>echo "Use l to move!!"<CR>')
-- vim.keymap.set('n', '<up>', '<cmd>echo "Use k to move!!"<CR>')
-- vim.keymap.set('n', '<down>', '<cmd>echo "Use j to move!!"<CR>')

-- Keybinds to make split navigation easier.
--  Use CTRL+<hjkl> to switch between windows
--
--  See `:help wincmd` for a list of all window commands
vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })
-- Buffer related mappings
-- Buffer zoom in/out
vim.keymap.set(
  'n',
  '<leader>bz',
  ':90 wincmd | <CR>',
  { desc = 'Zoom in, window width to 90' }
)
vim.keymap.set(
  'n',
  '<leader>bZ',
  ':180 wincmd | <CR>',
  { desc = 'Zoom out, window width to 180' }
)
-- Buffer alternate file
vim.keymap.set('n', '<leader>ba', '<C-^>', { desc = 'Alternate file' })
-- Close buffers
vim.keymap.set('n', '<leader>q', ':close <CR>', { desc = 'Close buffer' })
vim.keymap.set('n', '<leader>w', ':tabclose <CR>', { desc = 'Close tab' })

-- tmux uses Ctrl-A as its prefix, so we can't use it in Neovim. Let's remap some.
vim.keymap.set({ 'n', 'v' }, '<C-s>', '<C-a>', { noremap = true, silent = true })
vim.keymap.set({ 'n', 'v' }, 'g<C-s>', 'g<C-a>', { noremap = true, silent = true })

-- ─────────────────────────────────────────────────────────────────────────────
--  Basic Autocommands
--  See `:help lua-guide-autocommands`

-- Highlight when yanking (copying) text
--  Try it with `yap` in normal mode
--  See `:help vim.highlight.on_yank()`
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})

-- Python specific settings
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'python',
  callback = function()
    vim.bo.textwidth = 79
    vim.opt_local.wrap = false
  end,
})

-- Filetype patterns
vim.filetype.add {
  filename = {
    ['.todo'] = 'txt',
    ['dev-requirements.txt'] = 'requirements',
  },
  pattern = {
    ['requirements.*.txt'] = 'requirements',
    ['requirements.*.in'] = 'requirements',
  },
}

-- Auto-reload
vim.go.autoread = true
vim.api.nvim_create_autocmd({ 'FocusGained', 'CursorHold', 'CursorHoldI', 'BufEnter' }, {
  desc = 'Reload files when focus is gained',
  group = vim.api.nvim_create_augroup('kickstart-auto-reload', { clear = true }),
  callback = function()
    if vim.bo.modified then
      return
    end
    vim.cmd 'checktime'
  end,
})

-- ─────────────────────────────────────────────────────────────────────────────
-- [[ Install `lazy.nvim` plugin manager ]]

--    See `:help lazy.nvim.txt` or https://github.com/folke/lazy.nvim for more info
local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not vim.uv.fs_stat(lazypath) then
  local lazyrepo = 'https://github.com/folke/lazy.nvim.git'
  vim.fn.system {
    'git',
    'clone',
    '--filter=blob:none',
    '--branch=stable',
    lazyrepo,
    lazypath,
  }
end
vim.opt.rtp:prepend(lazypath)

require('lazy').setup({
  spec = {
    { import = 'custom.plugins.default' },
    {
      import = 'custom.plugins.local-only',
      cond = function()
        local hostname = vim.fn.system('hostname'):gsub('%s+$', '')
        if not string.find(hostname or '', 'neptune') then
          return false
        end
        return true
      end,
    },
  },
}, {
  ui = {
    -- If you have a Nerd Font, set icons to an empty table which will use the
    -- default lazy.nvim defined Nerd Font icons otherwise define a unicode icons table
    icons = vim.g.have_nerd_font and {} or {
      cmd = '⌘',
      config = '🛠',
      event = '📅',
      ft = '📂',
      init = '⚙',
      keys = '🗝',
      plugin = '🔌',
      runtime = '💻',
      require = '🌙',
      source = '📄',
      start = '🚀',
      task = '📌',
      lazy = '💤 ',
    },
  },
  checker = { enabled = true, notify = true },
})

-- vim: ts=2 sts=2 sw=2 et
