-- Theme setup ---------------------------------------------------------------

-- Treesitter setup -----------------------------------------------------------

require'nvim-treesitter.configs'.setup {
  -- A list of parser names, or "all" (the five listed parsers should always be installed)
  ensure_installed = { "c", "lua", "vim", "vimdoc", "query", "python", "comment"},

  -- Install parsers synchronously (only applied to `ensure_installed`)
  sync_install = false,

  -- Automatically install missing parsers when entering buffer
  -- Recommendation: set to false if you don't have `tree-sitter` CLI installed locally
  auto_install = true,

  highlight = {
    enable = true,

    -- NOTE: these are the names of the parsers and not the filetype. (for example if you want to
    -- disable highlighting for the `tex` filetype, you need to include `latex` in this list as this is
    -- the name of the parser)
    -- list of language that will be disabled
    -- disable = { "c", "rust" },

    -- Setting this to true will run `:h syntax` and tree-sitter at the same time.
    -- Set this to `true` if you depend on 'syntax' being enabled (like for indentation).
    -- Using this option may slow down your editor, and you may see some duplicate highlights.
    -- Instead of true it can also be a list of languages
    additional_vim_regex_highlighting = true,
  },

  incremental_selection = {
      enable = true,
      keymaps = {
        init_selection = "gnn", -- set to `false` to disable one of the mappings
        node_incremental = "grn",
        scope_incremental = "grc",
        node_decremental = "grm",
      },
    },
}

-- require("lspconfig").pylsp.setup({})
-- require("lspconfig").ruff_lsp.setup({})

require("chatgpt").setup({})

-- DAP configuration -----------------------------------------------------------
local dap, dapui = require("dap"), require("dapui")
local dap_python = require('dap-python')

dapui.setup({
    layouts = {
      {
        elements = {
          -- Other DAP UI elements you want to include in the layout
          'scopes',
          'breakpoints',
          'stacks',
          'watches',
        },
        size = 40,
        position = 'left',
      },
      {
        elements = {
          'console',
        },
        size = 40,
        position = 'right',
      },
      {
        elements = {
          'repl',
        },
        size = 90,
        position = 'right',
      },
    }
  })

dap_python.setup('~/.virtualenvs/debugpy/bin/python')
dap_python.test_runner = 'pytest'

-- dap.defaults.fallback.exception_breakpoints = {'raised'}
-- dap.set_exception_breakpoints()
dap.defaults.fallback.terminal_win_cmd = '100vsplit new'

vim.fn.sign_define('DapBreakpoint', {text='⊙', texthl='Todo', linehl='', numhl=''})
vim.fn.sign_define('DapStopped', {text='➡', texthl='Todo', linehl='TabLine', numhl=''})

dap.listeners.before.attach.dapui_config = function()
  dapui.open()
end
dap.listeners.before.launch.dapui_config = function()
  dapui.open()
end
dap.listeners.before.event_terminated.dapui_config = function()
  dapui.close()
end
dap.listeners.before.event_exited.dapui_config = function()
  dapui.close()
end

vim.keymap.set("n", "<Leader>dt", function()
 dapui.toggle()
end)

-- local widgets = require('dap.ui.widgets')
-- local scopes = widgets.scopes
-- local sidebar_scopes = widgets.sidebar(scopes, {width=48}, "rightbelow vsplit")
-- local sidebar_frames = widgets.sidebar(widgets.frames, {width=33}, "rightbelow vsplit")

-- vim.keymap.set("n", "<Leader>df", function()
--   sidebar_frames.toggle()
-- end)

-- vim.keymap.set("n", "<Leader>da", function()
--   sidebar_scopes.toggle()
-- end)

local function bufferTabOpen()
  -- Get the current cursor position
  local cur_pos = vim.api.nvim_win_get_cursor(0) -- Returns a table {row, col}

  -- Open the current buffer in a new tab
  -- Get the current buffer's file path
  local cur_buf_path = vim.api.nvim_buf_get_name(0)
  -- Command to open a new tab and edit the current buffer's file
  vim.cmd('tabnew ' .. cur_buf_path)
  vim.api.nvim_win_set_width(0, 220)

  -- Step 3: Set the cursor to the original position in the new tab
  -- Wait for the new tab to fully open and then set the cursor position
  vim.defer_fn(function()
    vim.api.nvim_win_set_cursor(0, cur_pos)
  end, 0) -- 0 ms delay to defer the function until after the command has completed
end

vim.keymap.set("n", "<Leader>dn", function()
  bufferTabOpen()
  dapui.open()
end)

vim.keymap.set("n", "<Leader>sd", function()
  bufferTabOpen()
  require("neotest").run.run({strategy = "dap"})
end)


require("coverage").setup({
  highlights = {
    covered = { fg = "#2aa198" },   -- supports style, fg, bg, sp (see :h highlight-gui)
    uncovered = { fg = "#dc322f" },
  },
  auto_reload = true,
})

-- testsubjects setup-----------------------------------------------------------
require('nvim-treesitter.configs').setup {
    textsubjects = {
        enable = true,
        prev_selection = ',', -- (Optional) keymap to select the previous selection
        keymaps = {
            ['.'] = 'textsubjects-smart',
            [';'] = 'textsubjects-container-outer',
            ['i;'] = 'textsubjects-container-inner',
            ['i;'] = { 'textsubjects-container-inner', desc = "Select inside containers (classes, functions, etc.)" },
        },
    },
}

-- Neotest and related setup ---------------------------------------------------
require("neotest").setup({
  adapters = {
    require("neotest-python")({
      dap = { justMyCode = false },
    }),
  },
})

-- Diagnostic setup -------------------------------------------------------------
-- function PrintDiagnostics(opts, bufnr, line_nr, client_id)
--   bufnr = bufnr or 0
--   line_nr = line_nr or (vim.api.nvim_win_get_cursor(0)[1] - 1)
--   opts = opts or {['lnum'] = line_nr}

--   local line_diagnostics = vim.diagnostic.get(bufnr, opts)
--   if vim.tbl_isempty(line_diagnostics) then return end

--   local diagnostic_message = ""
--   for i, diagnostic in ipairs(line_diagnostics) do
--     diagnostic_message = diagnostic_message .. string.format("%d: %s", i, diagnostic.message or "")
--     print(diagnostic_message)
--     if i ~= #line_diagnostics then
--       diagnostic_message = diagnostic_message .. "\n"
--     end
--   end
--   vim.api.nvim_echo({{diagnostic_message, "Normal"}}, false, {})
-- end
-- vim.cmd [[ autocmd! CursorHold * lua PrintDiagnostics() ]]
--
-- Aerial setup ----------------------------------------------------------------
require("aerial").setup({
    -- optionally use on_attach to set keymaps when aerial has attached to a buffer
    -- on_attach = function(bufnr)
    -- Jump forwards/backwards with '{' and '}'
    -- vim.keymap.set("n", "{", "<cmd>AerialPrev<CR>", { buffer = bufnr })
    -- vim.keymap.set("n", "}", "<cmd>AerialNext<CR>", { buffer = bufnr })
    -- end,
    backends = {"treesitter"},
    filter_kind = false,
    layout = {
      default_placement = "left",
      placement = "window",
    },
    close_automatic_events = {"unfocus"},

    nav = {
      border = "rounded",
      max_height = 0.9,
      min_height = { 10, 0.5 },
      max_width = 0.5,
      min_width = { 0.2, 20 },
      win_opts = {
        cursorline = true,
        winblend = 10,
      },
      -- Jump to symbol in source window when the cursor moves
      autojump = false,
      -- Show a preview of the code in the right column, when there are no child symbols
      preview = true,
    },
  })
