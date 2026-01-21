-- vim: ts=2 sts=2 sw=2 et
-- jujutsu/preview.lua - Preview window management and UI components

local M = {}

-- Lazy require to avoid circular dependency at load time
local function get_state()
  return require('jujutsu').state
end

local function get_const()
  return require('jujutsu').CONST
end

local function get_utils()
  return require('jujutsu').utils
end

local cursorline_ns = vim.api.nvim_create_namespace 'jujutsu_cursorline'

--------------------------------------------------------------------------------
-- Validation helpers
--------------------------------------------------------------------------------

local function is_win_valid(win)
  return win and vim.api.nvim_win_is_valid(win)
end

local function is_buf_valid(buf)
  return buf and vim.api.nvim_buf_is_valid(buf)
end

local function preview_is_valid()
  local state = get_state()
  return is_win_valid(state.preview.win) and is_buf_valid(state.preview.buf)
end

local function is_visual()
  local mode = vim.fn.mode()
  return mode == 'v' or mode == 'V' or mode == '\22'
end

--------------------------------------------------------------------------------
-- Colorization
--------------------------------------------------------------------------------

local function safe_colorize()
  if Snacks and Snacks.terminal and Snacks.terminal.colorize then
    local saved_listchars = vim.opt.listchars:get()
    Snacks.terminal.colorize()
    vim.opt.listchars = saved_listchars
  end
end

--------------------------------------------------------------------------------
-- Cursorline management
--------------------------------------------------------------------------------

function M.setup_dual_cursorline(buf, win)
  local augroup = vim.api.nvim_create_augroup('JujutsuCursorline', { clear = true })

  vim.api.nvim_create_autocmd({ 'CursorMoved', 'ModeChanged' }, {
    group = augroup,
    buffer = buf,
    callback = function()
      if not is_buf_valid(buf) or not is_win_valid(win) then
        return true
      end

      local state = get_state()
      vim.api.nvim_buf_clear_namespace(buf, cursorline_ns, 0, -1)

      local mode = vim.fn.mode()
      local ok, cursor = pcall(vim.api.nvim_win_get_cursor, win)
      if not ok then
        return true
      end
      local cursor_line = cursor[1]
      local line_count = vim.api.nvim_buf_line_count(buf)

      if mode == 'v' or mode == 'V' or mode == '\22' then
        -- Clear stored range when starting new visual selection
        state.stored_visual_range = nil

        local visual_start = vim.fn.line 'v'
        local start_line = math.min(visual_start, cursor_line)
        local end_line = math.max(visual_start, cursor_line)

        for line = start_line, end_line do
          vim.api.nvim_buf_set_extmark(buf, cursorline_ns, line - 1, 0, {
            line_hl_group = 'Visual',
          })
        end
        if end_line < line_count then
          vim.api.nvim_buf_set_extmark(buf, cursorline_ns, end_line, 0, {
            line_hl_group = 'Visual',
          })
        end
      elseif state.stored_visual_range then
        -- Use stored visual range (preserved when switching to preview)
        local start_line = state.stored_visual_range[1]
        local end_line = state.stored_visual_range[2]

        for line = start_line, end_line do
          vim.api.nvim_buf_set_extmark(buf, cursorline_ns, line - 1, 0, {
            line_hl_group = 'Visual',
          })
        end
        if end_line < line_count then
          vim.api.nvim_buf_set_extmark(buf, cursorline_ns, end_line, 0, {
            line_hl_group = 'Visual',
          })
        end
      else
        vim.api.nvim_buf_set_extmark(buf, cursorline_ns, cursor_line - 1, 0, {
          line_hl_group = 'CursorLine',
        })
        if cursor_line < line_count then
          vim.api.nvim_buf_set_extmark(buf, cursorline_ns, cursor_line, 0, {
            line_hl_group = 'CursorLine',
          })
        end
      end
    end,
  })

  vim.api.nvim_exec_autocmds('CursorMoved', { buffer = buf })
end

--------------------------------------------------------------------------------
-- Fold creation for diffs
--------------------------------------------------------------------------------

local function create_folds_for_diff(win, content_lines)
  vim.api.nvim_win_call(win, function()
    vim.wo.foldmethod = 'manual'
    vim.cmd 'normal! zE'
    vim.wo.foldenable = true
    vim.wo.foldlevel = 0

    local fold_starts = {}
    for i, line in ipairs(content_lines) do
      if line:match '^diff %-%-git' then
        table.insert(fold_starts, i)
      end
    end
    for i, start in ipairs(fold_starts) do
      local end_line = (fold_starts[i + 1] or (#content_lines + 1)) - 1
      if end_line > start then
        vim.cmd(string.format('%d,%dfold', start, end_line))
      end
    end
    vim.cmd 'normal! zM'
  end)
end

--------------------------------------------------------------------------------
-- Side-by-side diff
--------------------------------------------------------------------------------

function M.open_side_by_side_diff()
  local state = get_state()
  local utils = get_utils()

  local file_path = utils.get_diff_file_at_cursor()
  if not file_path then
    vim.notify('No file found at cursor position', vim.log.levels.WARN)
    return
  end
  local cid = state.preview.change_id
  if not cid then
    vim.notify('No change ID in preview', vim.log.levels.WARN)
    return
  end

  -- Handle range revsets (oldest::newest) vs single revisions
  local old_rev, new_rev
  local oldest, newest = cid:match '^([^:]+)::(.+)$'
  if oldest and newest then
    old_rev = oldest .. '-'
    new_rev = newest
  else
    old_rev = cid .. '-'
    new_rev = cid
  end

  local old_content = vim.fn.system(
    utils.build_jj_cmd('file show -r ' .. old_rev .. ' ' .. vim.fn.shellescape(file_path))
  )
  local new_content = vim.fn.system(
    utils.build_jj_cmd('file show -r ' .. new_rev .. ' ' .. vim.fn.shellescape(file_path))
  )
  local ft = vim.filetype.match { filename = file_path }

  local function setup_diff_buf(buf, content, suffix)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(content, '\n'))
    vim.bo[buf].buftype = 'nofile'
    vim.bo[buf].bufhidden = 'wipe'
    vim.bo[buf].buflisted = false
    vim.api.nvim_buf_set_name(buf, file_path .. suffix)
    if ft then
      vim.bo[buf].filetype = ft
    end
    vim.cmd 'diffthis'
  end

  local function close_diff_tab()
    vim.cmd 'diffoff!'
    vim.cmd 'tabclose'
  end

  vim.cmd 'tabnew'
  local old_buf = vim.api.nvim_get_current_buf()
  setup_diff_buf(old_buf, old_content, ' (' .. old_rev .. ')')

  vim.cmd 'rightbelow vsplit'
  local new_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(0, new_buf)
  setup_diff_buf(new_buf, new_content, ' (' .. new_rev .. ')')

  vim.keymap.set('n', 'gq', close_diff_tab, { buffer = old_buf, nowait = true })
  vim.keymap.set('n', 'gq', close_diff_tab, { buffer = new_buf, nowait = true })
end

--------------------------------------------------------------------------------
-- Preview keymaps
--------------------------------------------------------------------------------

-- Forward declaration for preview navigation
local preview_nav

local function setup_preview_keymaps(buf)
  local state = get_state()

  vim.keymap.set('n', 'O', M.open_side_by_side_diff, { buffer = buf, nowait = true })
  vim.keymap.set('n', '<CR>', M.open_side_by_side_diff, { buffer = buf, nowait = true })
  vim.keymap.set('n', '<leader>e', M.toggle_focus, { buffer = buf, nowait = true })

  -- Navigate revisions from preview (Tab/Shift-Tab)
  vim.keymap.set('n', '<Tab>', function()
    preview_nav 'j'
  end, { buffer = buf, nowait = true })
  vim.keymap.set('n', '<S-Tab>', function()
    preview_nav 'k'
  end, { buffer = buf, nowait = true })

  -- Close entire jj-log from preview buffer
  vim.keymap.set('n', 'gq', function()
    require('jujutsu').close()
  end, { buffer = buf, nowait = true })

  -- Intercept :tabclose to use proper cleanup (prevents crashes)
  vim.cmd.cnoreabbrev '<buffer> tabclose JJClose'
  vim.api.nvim_buf_create_user_command(buf, 'JJClose', function()
    require('jujutsu').close()
  end, { bang = true })
  -- Override <leader>w if user has it mapped to :tabclose
  vim.keymap.set('n', '<leader>w', function()
    require('jujutsu').close()
  end, { buffer = buf, nowait = true })
end

--------------------------------------------------------------------------------
-- Preview window operations
--------------------------------------------------------------------------------

function M.close()
  local state = get_state()

  if is_win_valid(state.preview.win) then
    vim.cmd('noautocmd call nvim_win_close(' .. state.preview.win .. ', v:true)')
  end
  if is_buf_valid(state.preview.buf) then
    vim.api.nvim_buf_delete(state.preview.buf, { force = true })
  end
  state.preview = { buf = nil, win = nil, type = nil, change_id = nil }
end

function M.toggle_focus()
  local state = get_state()

  -- Early exit if plugin was closed
  if not state.cwd then
    return
  end

  if preview_is_valid() then
    local current_win = vim.api.nvim_get_current_win()
    if current_win == state.preview.win then
      vim.api.nvim_set_current_win(state.win)
      -- Restore visual selection if we had one stored
      if state.stored_visual_range then
        local start_line = state.stored_visual_range[1]
        local end_line = state.stored_visual_range[2]
        state.stored_visual_range = nil
        vim.api.nvim_win_set_cursor(state.win, { start_line, 0 })
        vim.cmd 'normal! V'
        if end_line > start_line then
          vim.api.nvim_win_set_cursor(state.win, { end_line, 0 })
        end
      end
    else
      -- Store visual range before exiting, so highlighting persists
      if is_visual() then
        local start_line = vim.fn.line 'v'
        local end_line = vim.fn.line '.'
        if start_line > end_line then
          start_line, end_line = end_line, start_line
        end
        state.stored_visual_range = { start_line, end_line }
        vim.api.nvim_feedkeys(
          vim.api.nvim_replace_termcodes('<Esc>', true, false, true),
          'nx',
          false
        )
        -- Trigger cursorline update to show stored range
        vim.schedule(function()
          if is_buf_valid(state.buf) then
            vim.api.nvim_exec_autocmds('ModeChanged', { buffer = state.buf })
          end
        end)
      end
      vim.api.nvim_set_current_win(state.preview.win)
    end
  end
end

function M.open(content, preview_type, change_id, opts)
  opts = opts or {}
  local state = get_state()
  local CONST = get_const()

  -- Early exit if plugin was closed
  if not state.cwd then
    return nil
  end

  local log_cursor = is_win_valid(state.win) and vim.api.nvim_win_get_cursor(state.win)
    or nil

  -- Same content already showing? Do nothing
  if
    preview_is_valid()
    and state.preview.type == preview_type
    and state.preview.change_id == change_id
  then
    return state.preview.buf
  end

  local content_lines = vim.split(content, '\n')
  local created_new_window = false

  if preview_is_valid() then
    -- Reuse existing preview window
    vim.bo[state.preview.buf].filetype = opts.filetype or 'diff'
    vim.bo[state.preview.buf].modifiable = true
    vim.api.nvim_buf_set_lines(state.preview.buf, 0, -1, false, content_lines)
    vim.api.nvim_win_call(state.preview.win, function()
      if not opts.no_colorize then
        safe_colorize()
      end
      if opts.filetype == 'jujutsu' then
        create_folds_for_diff(state.preview.win, content_lines)
      end
    end)
    vim.bo[state.preview.buf].modifiable = false
  else
    created_new_window = true

    -- Clean up any existing JJ-preview buffer
    local existing = vim.fn.bufnr 'JJ-preview'
    if existing ~= -1 then
      vim.api.nvim_buf_delete(existing, { force = true })
    end

    local buf = vim.api.nvim_create_buf(false, true)
    local win
    local saved_splitkeep = vim.o.splitkeep
    vim.o.splitkeep = 'cursor'
    vim.api.nvim_win_call(state.win, function()
      vim.cmd 'noautocmd rightbelow vsplit'
      win = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_buf(win, buf)
    end)
    vim.o.splitkeep = saved_splitkeep

    state.preview.buf = buf
    state.preview.win = win

    vim.api.nvim_buf_set_name(buf, 'JJ-preview')
    vim.bo[buf].buftype = 'nofile'
    vim.bo[buf].bufhidden = 'wipe'
    vim.bo[buf].buflisted = false
    vim.bo[buf].filetype = opts.filetype or 'diff'

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, content_lines)

    if not opts.no_colorize then
      safe_colorize()
    end
    vim.bo[buf].modifiable = false

    if opts.filetype == 'jujutsu' then
      create_folds_for_diff(win, content_lines)
    end

    setup_preview_keymaps(buf)
  end

  state.preview.type = preview_type
  state.preview.change_id = change_id

  -- Return focus to log window only when we created a new window
  if created_new_window and is_win_valid(state.win) then
    vim.api.nvim_set_current_win(state.win)
    if log_cursor then
      vim.api.nvim_win_set_cursor(state.win, log_cursor)
    end
  end

  return state.preview.buf
end

function M.refresh()
  local state = get_state()
  local utils = get_utils()

  -- Early exit if plugin was closed
  if
    not state.cwd
    or not preview_is_valid()
    or not state.preview.change_id
    or utils.has_active_job()
  then
    return
  end

  local id = state.preview.change_id
  local preview_type = state.preview.type
  local cmd = preview_type == 'diff' and ('diff -r ' .. id .. ' --git')
    or ('show -r ' .. id .. ' --git')

  local output = vim.fn.system(utils.build_jj_cmd(cmd))

  -- Clear cached change_id to force update
  state.preview.change_id = nil
  M.open(output, preview_type, id, { filetype = 'jujutsu', no_colorize = true })
end

--------------------------------------------------------------------------------
-- Preview navigation from preview window
--------------------------------------------------------------------------------

preview_nav = function(direction)
  local state = get_state()
  local utils = get_utils()

  -- Early exit if plugin was closed
  if
    not state.cwd
    or not is_win_valid(state.win)
    or not is_buf_valid(state.buf)
    or utils.has_active_job()
  then
    return
  end

  -- Don't navigate if there's a visual selection
  if state.stored_visual_range then
    return
  end

  local preview_id = state.preview.change_id
  if not preview_id then
    return
  end

  -- Handle range revsets - use newest for positioning
  local target_id = preview_id:match '::(.+)$' or preview_id

  -- Build list of (line_number, change_id) from log buffer
  local lines = vim.api.nvim_buf_get_lines(state.buf, 0, -1, false)
  local commits = {}
  for i, line in ipairs(lines) do
    local line_id = utils.get_change_id_from_line(line)
    if line_id then
      table.insert(commits, { line = i, id = line_id })
    end
  end

  -- Find current position and calculate next/previous
  local current_idx = nil
  for i, commit in ipairs(commits) do
    if commit.id == target_id then
      current_idx = i
      break
    end
  end

  if not current_idx then
    return
  end

  local new_idx = direction == 'j' and (current_idx + 1) or (current_idx - 1)
  if new_idx < 1 or new_idx > #commits then
    return
  end

  local new_commit = commits[new_idx]

  -- Move cursor in log buffer and scroll to show it
  vim.api.nvim_win_call(state.win, function()
    vim.api.nvim_win_set_cursor(state.win, { new_commit.line, 0 })
    vim.cmd 'normal! zz'
  end)

  -- Update preview
  local output =
    vim.fn.system(utils.build_jj_cmd('show -r ' .. new_commit.id .. ' --git'))
  M.open(output, 'show', new_commit.id, { filetype = 'jujutsu', no_colorize = true })
end

--------------------------------------------------------------------------------
-- Help window
--------------------------------------------------------------------------------

function M.show_help()
  local CONST = get_const()

  local help_lines = {
    '  Jujutsu Flog - Keybindings',
    '  ──────────────────────────',
    '',
    '  Commit (c-prefix):',
    '  cn    new       - New commit after this one',
    '  cN    new @     - New commit after current',
    '  cd    describe  - Edit description (<CR> save, q cancel)',
    '  cD    cdescribe - AI-generate description (interactive)',
    '  cs    squash    - Squash commit (visual: squash range)',
    '  cS    squash    - Squash into selected target (pick from list)',
    '',
    '  Rebase (r-prefix):',
    '  rr    rebase    - Rebase revision(s) onto another',
    '  ri    rebase    - Rebase with mode selection (before/after/onto)',
    '  rd    duplicate - Duplicate revision(s) with mode selection',
    '  rw    switch    - Switch revision with parent',
    '  rp    parallelize - Parallelize revisions (visual only)',
    '',
    '  Bookmark (b-prefix):',
    '  bb    bookmark  - Set bookmark on commit',
    '  bm    bookmark  - Move bookmark to commit',
    '  bM    bookmark  - Move bookmark to commit with --allow-backwards',
    '',
    '  Git (g-prefix):',
    '  gf    fetch     - Git fetch from remote',
    '  gp    push      - Git push all bookmarks',
    '  gP    push      - Git push selected bookmark',
    '',
    '  Actions:',
    '  e     edit      - Edit (checkout) commit',
    '  x     abandon   - Abandon commit (confirm)',
    '  y     yank      - Yank revision(s) (visual: earliest::latest)',
    '  a     absorb    - Absorb working copy changes into revision',
    '  L     split     - Split revision',
    '  u     undo      - Undo last operation',
    '  U     redo      - Redo last undo',
    '',
    '  Navigation:',
    '  j/k       move  - Move by commit (2 lines)',
    '  <Tab>     next  - Navigate to next revision (in preview)',
    '  <S-Tab>   prev  - Navigate to previous revision (in preview)',
    '  <CR>      focus - Toggle log/preview focus',
    '  O/<CR>    diff  - Open file diff side-by-side (in preview)',
    '  g?        help  - Show this help',
    '  gq        close - Close flog',
  }

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, help_lines)

  local height = #help_lines + 2
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - CONST.HELP_WIDTH) / 2),
    width = CONST.HELP_WIDTH,
    height = height,
    border = 'rounded',
    style = 'minimal',
    title = ' Help ',
    title_pos = 'center',
  })

  local close_help = function()
    vim.api.nvim_win_close(win, true)
  end
  vim.keymap.set('n', 'q', close_help, { buffer = buf, nowait = true })
  vim.keymap.set('n', '<Esc>', close_help, { buffer = buf, nowait = true })
  vim.keymap.set('n', '?', close_help, { buffer = buf, nowait = true })
end

return M
