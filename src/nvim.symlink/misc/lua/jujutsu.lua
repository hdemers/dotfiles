-- vim: ts=2 sts=2 sw=2 et
-- jujutsu.lua - A flog-inspired Jujutsu log viewer for Neovim

--------------------------------------------------------------------------------
-- 1. Module & Constants
--------------------------------------------------------------------------------

local M = {}

local CONST = {
  CHANGE_ID_LENGTH = 8,
  LINES_PER_COMMIT = 2,
  EDITOR_POLL_INTERVAL_MS = 100,
  EDITOR_POLL_MAX_ATTEMPTS = 50,
  CURSOR_RESTORE_DELAY_MS = 100,
  FLOAT_WIDTH = 100,
  HELP_WIDTH = 63,
}

local cursorline_ns = vim.api.nvim_create_namespace 'jujutsu_cursorline'

--------------------------------------------------------------------------------
-- 2. State Management
--------------------------------------------------------------------------------

M.state = {
  buf = nil,
  win = nil,
  cwd = nil,
  preview = {
    buf = nil,
    win = nil,
    type = nil, -- 'diff' or 'show'
    change_id = nil,
  },
  stored_visual_range = nil, -- { start_line, end_line } when visual selection is preserved
  active_job = nil, -- Current async jj job ID (for cancellation)
  debounce_timer = nil, -- Timer for debounced preview updates
}

local function is_win_valid(win)
  return win and vim.api.nvim_win_is_valid(win)
end

local function is_buf_valid(buf)
  return buf and vim.api.nvim_buf_is_valid(buf)
end

local function state_is_valid()
  return is_win_valid(M.state.win) and is_buf_valid(M.state.buf)
end

local function preview_is_valid()
  return is_win_valid(M.state.preview.win) and is_buf_valid(M.state.preview.buf)
end

local function is_visual()
  local mode = vim.fn.mode()
  return mode == 'v' or mode == 'V' or mode == '\22'
end

-- Cancel any pending debounced operation
local function cancel_debounce()
  if M.state.debounce_timer then
    M.state.debounce_timer:stop()
    M.state.debounce_timer:close()
    M.state.debounce_timer = nil
  end
end

-- Debounce a function call (cancels previous pending call)
local function debounce(fn, delay_ms)
  cancel_debounce()
  M.state.debounce_timer = vim.uv.new_timer()
  M.state.debounce_timer:start(delay_ms, 0, vim.schedule_wrap(function()
    cancel_debounce()
    fn()
  end))
end

-- Track and cancel active async jj jobs
local function set_active_job(job_id)
  -- Cancel previous job if still running
  if M.state.active_job and vim.fn.jobwait({ M.state.active_job }, 0)[1] == -1 then
    vim.fn.jobstop(M.state.active_job)
  end
  M.state.active_job = job_id
end

local function clear_active_job()
  M.state.active_job = nil
end

local function has_active_job()
  return M.state.active_job and vim.fn.jobwait({ M.state.active_job }, 0)[1] == -1
end

local function exit_visual_mode()
  vim.api.nvim_feedkeys(
    vim.api.nvim_replace_termcodes('<Esc>', true, false, true),
    'nx',
    false
  )
end

--------------------------------------------------------------------------------
-- 3. Utilities
--------------------------------------------------------------------------------

local function safe_colorize()
  if Snacks and Snacks.terminal and Snacks.terminal.colorize then
    local saved_listchars = vim.opt.listchars:get()
    Snacks.terminal.colorize()
    vim.opt.listchars = saved_listchars
  end
end

local function strip_ansi(str)
  return str:gsub('\027%[[%d;]*m', '')
end

local function get_change_id_from_line(line)
  local clean = strip_ansi(line)
  -- Match change ID: lowercase letters/numbers after graph chars, followed by commit_id
  -- This ensures we only match the first line of a commit (not description lines)
  local change_id = clean:match '[│◆○@◉~%s]+([a-z][a-z0-9]+)%s+[a-z0-9]+'
  if change_id and #change_id >= CONST.CHANGE_ID_LENGTH then
    return change_id:sub(1, CONST.CHANGE_ID_LENGTH)
  end
  return nil
end

local function get_change_id_under_cursor()
  return get_change_id_from_line(vim.api.nvim_get_current_line())
end

local function is_jujutsu_repo()
  local path = vim.fn.getcwd()
  while path ~= '/' do
    if vim.fn.isdirectory(path .. '/.jj') == 1 then
      return true
    end
    path = vim.fn.fnamemodify(path, ':h')
  end
  return false
end

local function get_diff_file_at_cursor()
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
  local lines =
    vim.api.nvim_buf_get_lines(vim.api.nvim_get_current_buf(), 0, cursor_line, false)
  for i = #lines, 1, -1 do
    local match = lines[i]:match '^diff %-%-git a/(.-) b/'
    if match then
      return match
    end
  end
  return nil
end

local DEFAULT_REVISION_TEMPLATE =
  'change_id.shortest() ++ " (" ++ commit_id.shortest() ++ ") " ++ bookmarks ++ " " ++ description.first_line()'

--------------------------------------------------------------------------------
-- 4. Command Execution Layer
--------------------------------------------------------------------------------

local function build_jj_cmd(args, cwd)
  cwd = cwd or M.state.cwd
  local parts = { 'cd', vim.fn.shellescape(cwd), '&&', 'jj' }
  if type(args) == 'string' then
    table.insert(parts, args)
  else
    for _, arg in ipairs(args) do
      table.insert(parts, arg)
    end
  end
  return table.concat(parts, ' ')
end

local function run_jj_cmd(cmd, change_id, opts)
  opts = opts or {}
  local args = change_id and (cmd .. ' ' .. change_id) or cmd
  local full_cmd = build_jj_cmd(args)
  local output = vim.fn.system(full_cmd)
  local success = vim.v.shell_error == 0

  if opts.notify ~= false then
    local level = success and vim.log.levels.INFO or vim.log.levels.ERROR
    vim.notify(output, level)
  end

  return output, success
end

local function get_revisions(opts)
  opts = opts or {}
  local revset = opts.revset or 'trunk()::'
  local template = opts.template or DEFAULT_REVISION_TEMPLATE

  local cmd = 'log -r '
    .. vim.fn.shellescape(revset)
    .. ' --no-graph --template '
    .. vim.fn.shellescape(template .. ' ++ "\\n"')
  local output, success = run_jj_cmd(cmd, nil, { notify = false })
  if not success then
    return nil
  end

  local revisions = {}
  for line in output:gmatch '[^\n]+' do
    if line ~= '' then
      table.insert(revisions, line)
    end
  end
  return revisions
end

-- Forward declaration for refresh_log (used in run_jj_with_editor)
local refresh_log

-- Create temporary session for jj editor interaction
local function create_editor_session(jj_args)
  local session_dir = vim.fn.tempname()
  vim.fn.mkdir(session_dir, 'p')

  local session = {
    dir = session_dir,
    file_marker = session_dir .. '/jj_file',
    waiting_marker = session_dir .. '/waiting',
    editor_script = session_dir .. '/editor.sh',
    saved_cursor = is_win_valid(M.state.win) and vim.api.nvim_win_get_cursor(M.state.win)
      or nil,
  }

  vim.fn.writefile({}, session.waiting_marker)
  vim.fn.writefile({
    '#!/bin/sh',
    'echo "$1" > "' .. session.file_marker .. '"',
    'while [ -f "' .. session.waiting_marker .. '" ]; do sleep 0.1; done',
    'exit 0',
  }, session.editor_script)
  vim.fn.setfperm(session.editor_script, 'rwx------')

  session.cmd = string.format(
    'cd %s && JJ_EDITOR=%s jj %s 2>&1',
    vim.fn.shellescape(M.state.cwd),
    vim.fn.shellescape(session.editor_script),
    jj_args
  )

  return session
end

-- Open floating editor window for jj
local function open_editor_float(session, job_id, title)
  local lines = vim.fn.readfile(session.file_marker)
  if #lines == 0 or lines[1] == '' then
    return false
  end

  local buf = vim.fn.bufadd(lines[1])
  vim.fn.bufload(buf)

  local height = math.floor(vim.o.lines * 0.5)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - CONST.FLOAT_WIDTH) / 2),
    width = CONST.FLOAT_WIDTH,
    height = height,
    border = 'rounded',
    title = title .. '│ <CR> save │ q cancel ',
    title_pos = 'center',
  })

  vim.bo[buf].filetype = 'jjdescription'
  vim.wo[win].wrap = true
  vim.wo[win].cursorline = false

  local closed = false
  local function cleanup()
    if closed then
      return
    end
    closed = true
    vim.fn.delete(session.waiting_marker)
  end

  local function finish_edit()
    closed = true
    vim.api.nvim_buf_call(buf, function()
      vim.cmd 'silent! write!'
    end)
    if session.saved_cursor and is_win_valid(M.state.win) then
      pcall(vim.api.nvim_win_set_cursor, M.state.win, session.saved_cursor)
    end
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    vim.defer_fn(function()
      vim.fn.delete(session.waiting_marker)
    end, CONST.CURSOR_RESTORE_DELAY_MS)
  end

  local function cancel_edit()
    vim.fn.jobstop(job_id)
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    cleanup()
  end

  vim.api.nvim_create_autocmd('WinClosed', {
    pattern = tostring(win),
    once = true,
    callback = function()
      if not closed then
        vim.fn.jobstop(job_id)
        cleanup()
      end
    end,
  })

  vim.keymap.set('n', '<CR>', finish_edit, { buffer = buf, nowait = true })
  vim.keymap.set('n', 'q', cancel_edit, { buffer = buf, nowait = true })
  return true
end

local function run_jj_with_editor(jj_args, title, on_complete)
  local session = create_editor_session(jj_args)

  -- Cancel any pending preview updates
  cancel_debounce()

  local jj_output = {}
  local job_id = vim.fn.jobstart(session.cmd, {
    on_stdout = function(_, data)
      vim.list_extend(jj_output, data)
    end,
    on_stderr = function(_, data)
      vim.list_extend(jj_output, data)
    end,
    on_exit = function(_, exit_code)
      clear_active_job()
      vim.fn.delete(session.dir, 'rf')
      local output = table.concat(jj_output, '\n'):gsub('^%s+', ''):gsub('%s+$', '')
      if exit_code == 0 then
        if output ~= '' then
          vim.notify(output, vim.log.levels.INFO)
        end
        refresh_log(session.saved_cursor)
      elseif output ~= '' and not output:match 'interrupt' then
        vim.notify(output, vim.log.levels.ERROR)
      end
      if on_complete then
        on_complete(exit_code == 0)
      end
    end,
  })

  if job_id <= 0 then
    vim.fn.delete(session.dir, 'rf')
    vim.notify('Failed to start jj', vim.log.levels.ERROR)
    return
  end

  set_active_job(job_id)

  local attempts = 0
  local function poll_for_editor()
    attempts = attempts + 1
    if vim.fn.filereadable(session.file_marker) == 1 then
      if open_editor_float(session, job_id, title) then
        return
      end
    end

    if attempts < CONST.EDITOR_POLL_MAX_ATTEMPTS then
      vim.defer_fn(poll_for_editor, CONST.EDITOR_POLL_INTERVAL_MS)
    else
      vim.fn.jobstop(job_id)
      vim.fn.delete(session.dir, 'rf')
      vim.notify('Timeout waiting for jj', vim.log.levels.ERROR)
    end
  end

  vim.defer_fn(poll_for_editor, CONST.EDITOR_POLL_INTERVAL_MS)
end

--------------------------------------------------------------------------------
-- 5. UI Components
--------------------------------------------------------------------------------

local function setup_dual_cursorline(buf, win)
  vim.api.nvim_create_autocmd({ 'CursorMoved', 'ModeChanged' }, {
    buffer = buf,
    callback = function()
      if not is_buf_valid(buf) then
        return true
      end

      vim.api.nvim_buf_clear_namespace(buf, cursorline_ns, 0, -1)

      local mode = vim.fn.mode()
      local cursor_line = vim.api.nvim_win_get_cursor(win)[1]
      local line_count = vim.api.nvim_buf_line_count(buf)

      if mode == 'v' or mode == 'V' or mode == '\22' then
        -- Clear stored range when starting new visual selection
        M.state.stored_visual_range = nil

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
      elseif M.state.stored_visual_range then
        -- Use stored visual range (preserved when switching to preview)
        local start_line = M.state.stored_visual_range[1]
        local end_line = M.state.stored_visual_range[2]

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

-- Preview window management
local preview = {}

-- Open side-by-side diff in a new tab
local function open_side_by_side_diff()
  local file_path = get_diff_file_at_cursor()
  if not file_path then
    vim.notify('No file found at cursor position', vim.log.levels.WARN)
    return
  end
  local cid = M.state.preview.change_id
  if not cid then
    vim.notify('No change ID in preview', vim.log.levels.WARN)
    return
  end

  -- Handle range revsets (oldest::newest) vs single revisions
  local old_rev, new_rev
  local oldest, newest = cid:match '^([^:]+)::(.+)$'
  if oldest and newest then
    -- Range: show file before oldest and at newest
    old_rev = oldest .. '-'
    new_rev = newest
  else
    -- Single revision: show file before and at this revision
    old_rev = cid .. '-'
    new_rev = cid
  end

  local old_content = vim.fn.system(
    build_jj_cmd('file show -r ' .. old_rev .. ' ' .. vim.fn.shellescape(file_path))
  )
  local new_content = vim.fn.system(
    build_jj_cmd('file show -r ' .. new_rev .. ' ' .. vim.fn.shellescape(file_path))
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

  vim.keymap.set('n', 'q', close_diff_tab, { buffer = old_buf, nowait = true })
  vim.keymap.set('n', 'q', close_diff_tab, { buffer = new_buf, nowait = true })
end

-- Forward declaration for preview navigation (defined after nav())
local preview_nav

local function setup_preview_keymaps(buf)
  vim.keymap.set('n', 'q', function()
    preview.close()
    if is_win_valid(M.state.win) then
      vim.api.nvim_set_current_win(M.state.win)
    end
  end, { buffer = buf, nowait = true })

  vim.keymap.set('n', 'O', open_side_by_side_diff, { buffer = buf, nowait = true })
  vim.keymap.set('n', '<CR>', open_side_by_side_diff, { buffer = buf, nowait = true })
  vim.keymap.set('n', '<Tab>', preview.toggle_focus, { buffer = buf, nowait = true })

  -- Navigate revisions from preview (J/K)
  vim.keymap.set('n', 'J', function()
    preview_nav 'j'
  end, { buffer = buf, nowait = true })
  vim.keymap.set('n', 'K', function()
    preview_nav 'k'
  end, { buffer = buf, nowait = true })
end

function preview.close()
  if is_win_valid(M.state.preview.win) then
    vim.cmd('noautocmd call nvim_win_close(' .. M.state.preview.win .. ', v:true)')
  end
  if is_buf_valid(M.state.preview.buf) then
    vim.api.nvim_buf_delete(M.state.preview.buf, { force = true })
  end
  M.state.preview = { buf = nil, win = nil, type = nil, change_id = nil }
end

function preview.toggle_focus()
  if preview_is_valid() then
    local current_win = vim.api.nvim_get_current_win()
    if current_win == M.state.preview.win then
      vim.api.nvim_set_current_win(M.state.win)
      -- Restore visual selection if we had one stored
      if M.state.stored_visual_range then
        local start_line = M.state.stored_visual_range[1]
        local end_line = M.state.stored_visual_range[2]
        M.state.stored_visual_range = nil
        vim.api.nvim_win_set_cursor(M.state.win, { start_line, 0 })
        vim.cmd 'normal! V'
        if end_line > start_line then
          vim.api.nvim_win_set_cursor(M.state.win, { end_line, 0 })
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
        M.state.stored_visual_range = { start_line, end_line }
        exit_visual_mode()
        -- Trigger cursorline update to show stored range
        vim.schedule(function()
          if is_buf_valid(M.state.buf) then
            vim.api.nvim_exec_autocmds('ModeChanged', { buffer = M.state.buf })
          end
        end)
      end
      vim.api.nvim_set_current_win(M.state.preview.win)
    end
  end
end

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

function preview.open(content, preview_type, change_id, opts)
  opts = opts or {}

  local log_cursor = is_win_valid(M.state.win)
      and vim.api.nvim_win_get_cursor(M.state.win)
    or nil

  -- Same content already showing? Do nothing
  if
    preview_is_valid()
    and M.state.preview.type == preview_type
    and M.state.preview.change_id == change_id
  then
    return M.state.preview.buf
  end

  local content_lines = vim.split(content, '\n')

  local created_new_window = false

  if preview_is_valid() then
    -- Reuse existing preview window - update buffer without switching windows
    vim.bo[M.state.preview.buf].filetype = opts.filetype or 'diff'
    vim.bo[M.state.preview.buf].modifiable = true
    vim.api.nvim_buf_set_lines(M.state.preview.buf, 0, -1, false, content_lines)
    vim.api.nvim_win_call(M.state.preview.win, function()
      if not opts.no_colorize then
        safe_colorize()
      end
      if opts.filetype == 'jujutsu' then
        create_folds_for_diff(M.state.preview.win, content_lines)
      end
    end)
    vim.bo[M.state.preview.buf].modifiable = false
  else
    created_new_window = true
    -- Create new preview window
    local buf = vim.api.nvim_create_buf(false, true)

    local win
    local saved_splitkeep = vim.o.splitkeep
    vim.o.splitkeep = 'cursor'
    vim.api.nvim_win_call(M.state.win, function()
      vim.cmd 'noautocmd rightbelow vsplit'
      win = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_buf(win, buf)
    end)
    vim.o.splitkeep = saved_splitkeep

    M.state.preview.buf = buf
    M.state.preview.win = win

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

  M.state.preview.type = preview_type
  M.state.preview.change_id = change_id

  -- Return focus to log window only when we created a new window
  -- (updating existing preview doesn't change focus, so no need to restore)
  if created_new_window and is_win_valid(M.state.win) then
    vim.api.nvim_set_current_win(M.state.win)
    if log_cursor then
      vim.api.nvim_win_set_cursor(M.state.win, log_cursor)
    end
  end

  return M.state.preview.buf
end

-- Refresh preview with current change_id (re-fetch content)
function preview.refresh()
  if not preview_is_valid() or not M.state.preview.change_id or has_active_job() then
    return
  end

  local id = M.state.preview.change_id
  local preview_type = M.state.preview.type
  local cmd = preview_type == 'diff' and ('diff -r ' .. id .. ' --git')
    or ('show -r ' .. id .. ' --git')

  local output = vim.fn.system(build_jj_cmd(cmd))

  -- Clear cached change_id to force update
  M.state.preview.change_id = nil
  preview.open(output, preview_type, id, { filetype = 'jujutsu', no_colorize = true })
end

local function show_help()
  local help_lines = {
    '  Jujutsu Flog - Keybindings',
    '  ──────────────────────────',
    '  Preview (toggle, reuses pane):',
    '  <CR>  show      - Show commit details (visual: range diff)',
    '  D     cdescribe - AI-generate description (interactive)',
    '  d     describe  - Edit description (<CR> save, q cancel)',
    '  s     squash    - Squash commit (visual: squash range)',
    '  S     squash    - Squash into selected target (pick from list)',
    '  O/<CR> split    - Open file diff side-by-side (in preview)',
    '                    (works with visual range selection)',
    '',
    '  Actions:',
    '  e     edit     - Edit (checkout) commit',
    '  n     new      - New commit after this one',
    '  N     new @    - New commit after current',
    '  x     abandon  - Abandon commit (confirm)',
    '  b     bookmark - Set bookmark on commit',
    '  u     undo     - Undo last operation',
    '  r     redo     - Redo last undo',
    '  R     rebase   - Rebase revision(s) onto another',
    '',
    '  Navigation:',
    '  j/k   move     - Move by commit (2 lines)',
    '  J/K   move     - Navigate revisions from preview',
    '  <Tab> focus    - Toggle log/preview focus',
    '  ?     help     - Show this help',
    '  q/Esc close    - Close flog (log) / preview',
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

--------------------------------------------------------------------------------
-- 6. Action Framework
--------------------------------------------------------------------------------

--- Get revset from current context (cursor or visual selection)
--- Does NOT exit visual mode - use for preview/read-only operations
---@return string|nil revset
local function get_revset()
  if not is_visual() then
    return get_change_id_under_cursor()
  end

  local start_line = vim.fn.line 'v'
  local end_line = vim.fn.line '.'
  if start_line > end_line then
    start_line, end_line = end_line, start_line
  end

  local lines = vim.api.nvim_buf_get_lines(M.state.buf, start_line - 1, end_line, false)
  local change_ids = {}
  local seen = {}
  for _, line in ipairs(lines) do
    local id = get_change_id_from_line(line)
    if id and not seen[id] then
      table.insert(change_ids, id)
      seen[id] = true
    end
  end

  if #change_ids == 0 then
    return nil
  elseif #change_ids == 1 then
    return change_ids[1]
  else
    return change_ids[#change_ids] .. '::' .. change_ids[1] -- oldest::newest
  end
end

--- Execute an action with a revset (single revision or range)
--- In visual mode: exits visual mode before running action
---@param action_fn function(revset: string, chosen?: string)
---@param opts? { refresh?: boolean, choose_from?: string }
---@return function
local function with_change_id(action_fn, opts)
  opts = opts or {}
  return function()
    local was_visual = is_visual()
    local revset = get_revset()

    if not revset then
      local msg = was_visual and 'No change IDs found in selection'
        or 'No change ID found on this line'
      vim.notify(msg, vim.log.levels.WARN)
      return
    end

    local function run_action(chosen)
      action_fn(revset, chosen)
      if opts.refresh ~= false then
        refresh_log()
      end
    end

    local function execute_action()
      if opts.choose_from then
        local destinations = get_revisions { revset = opts.choose_from }
        if not destinations or #destinations == 0 then
          vim.notify('No revisions found from: ' .. opts.choose_from, vim.log.levels.WARN)
          return
        end

        vim.ui.select(destinations, {
          prompt = 'Select target revision:',
          format_item = function(item)
            return item
          end,
        }, function(choice)
          if not choice then
            return
          end
          local chosen_id = choice:match '^(%S+)'
          if chosen_id then
            run_action(chosen_id)
          end
        end)
      else
        run_action()
      end
    end

    if was_visual then
      exit_visual_mode()
      vim.schedule(execute_action)
    else
      execute_action()
    end
  end
end

-- Refresh preview with revision under cursor (called after log refresh)
local function refresh_preview_after_log()
  if not preview_is_valid() or has_active_job() then
    return
  end
  vim.schedule(function()
    if not preview_is_valid() or not is_win_valid(M.state.win) or has_active_job() then
      return
    end
    -- Ensure we're in the log window
    local prev_win = vim.api.nvim_get_current_win()
    vim.api.nvim_set_current_win(M.state.win)

    local id = get_change_id_under_cursor()
    if id then
      local preview_type = M.state.preview.type or 'show'
      local cmd = preview_type == 'diff' and ('diff -r ' .. id .. ' --git')
        or ('show -r ' .. id .. ' --git')
      local output = vim.fn.system(build_jj_cmd(cmd))
      M.state.preview.change_id = nil -- force update
      preview.open(output, preview_type, id, { filetype = 'jujutsu', no_colorize = true })
    end

    -- Restore previous window if different
    if prev_win ~= M.state.win and vim.api.nvim_win_is_valid(prev_win) then
      vim.api.nvim_set_current_win(prev_win)
    end
  end)
end

-- Define refresh_log (uses existing buffer, keymaps already attached)
refresh_log = function(cursor_pos)
  if not state_is_valid() then
    return
  end

  cursor_pos = cursor_pos or vim.api.nvim_win_get_cursor(M.state.win)

  local output = vim.fn.system(build_jj_cmd 'log -r :: --color=always')
  local lines = vim.split(output, '\n')

  -- Reuse existing buffer - update contents in place
  vim.bo[M.state.buf].modifiable = true
  vim.api.nvim_buf_set_lines(M.state.buf, 0, -1, false, lines)

  -- Compute row based on NEW content
  local line_count = #lines
  local row = math.min(cursor_pos[1], line_count)
  local col = cursor_pos[2] or 0

  -- Restore cursor BEFORE colorize
  pcall(vim.api.nvim_win_set_cursor, M.state.win, { row, col })

  vim.api.nvim_win_call(M.state.win, function()
    safe_colorize()
  end)
  vim.bo[M.state.buf].modifiable = false

  -- Restore cursor AFTER colorize (it may have moved it)
  pcall(vim.api.nvim_win_set_cursor, M.state.win, { row, col })

  -- Debounced preview refresh - will be cancelled if new operation starts
  debounce(function()
    if is_win_valid(M.state.win) then
      pcall(vim.api.nvim_win_set_cursor, M.state.win, { row, col })
    end
    refresh_preview_after_log()
  end, CONST.CURSOR_RESTORE_DELAY_MS)
end

local function close_flog()
  cancel_debounce()
  preview.close()
  if is_buf_valid(M.state.buf) then
    vim.cmd 'tabclose'
  end
  M.state.win = nil
  M.state.buf = nil
  M.state.active_job = nil
end

-- Action definitions using the wrapper pattern
local actions = {}

actions.edit = with_change_id(function(id)
  run_jj_cmd('edit', id)
end)

actions.new = with_change_id(function(id)
  run_jj_cmd('new', id)
end)

actions.new_current = function()
  run_jj_cmd('new', '')
  refresh_log()
end

actions.describe = with_change_id(function(id)
  run_jj_with_editor('describe ' .. id, ' Describe ' .. id .. ' ')
end, { refresh = false }) -- refresh handled by editor callback

actions.diff = with_change_id(function(id)
  local output = vim.fn.system(build_jj_cmd('diff -r ' .. id .. ' --git'))
  preview.open(output, 'diff', id, { filetype = 'jujutsu', no_colorize = true })
end, { refresh = false })

actions.show = with_change_id(function(id)
  local cursor = vim.api.nvim_win_get_cursor(M.state.win)
  local win = M.state.win

  -- Use diff for ranges (oldest::newest), show for single revisions
  local is_range = id:find '::'
  local cmd = is_range and ('diff -r ' .. id .. ' --git')
    or ('show -r ' .. id .. ' --git')
  local preview_type = is_range and 'diff' or 'show'

  local output = vim.fn.system(build_jj_cmd(cmd))
  preview.open(output, preview_type, id, { filetype = 'jujutsu', no_colorize = true })

  vim.defer_fn(function()
    if is_win_valid(win) then
      vim.api.nvim_win_set_cursor(win, cursor)
    end
  end, 10)
end, { refresh = false })

actions.squash = with_change_id(function(revset, target)
  local cmd
  if target then
    -- Squash into explicit target
    cmd = string.format('squash -f %s -t %s', revset, target)
  elseif revset:find '::' then
    local oldest = revset:match '^([^:]+)'
    cmd = string.format('squash -f %s -t %s', revset, oldest)
  else
    cmd = 'squash -r ' .. revset
  end
  run_jj_with_editor(cmd, ' Squash ' .. revset .. ' ')
end, { refresh = false })

actions.squash_into = with_change_id(function(revset, target)
  local cmd = string.format('squash -f %s -t %s', revset, target)
  run_jj_with_editor(cmd, ' Squash ' .. revset .. ' into ' .. target .. ' ')
end, { refresh = false, choose_from = 'trunk()..' })

actions.abandon = with_change_id(function(id)
  vim.ui.select({ 'Yes', 'No' }, { prompt = 'Abandon ' .. id .. '?' }, function(choice)
    if choice == 'Yes' then
      run_jj_cmd('abandon', id)
      refresh_log()
    end
  end)
end, { refresh = false }) -- refresh handled in callback

actions.bookmark = with_change_id(function(id)
  vim.ui.input({ prompt = 'Bookmark name: ' }, function(name)
    if name and name ~= '' then
      run_jj_cmd('bookmark', 'set ' .. name .. ' -r ' .. id)
      refresh_log()
    end
  end)
end, { refresh = false }) -- refresh handled in callback

actions.rebase = with_change_id(function(revset)
  local destinations = get_revisions()
  if not destinations or #destinations == 0 then
    vim.notify('No destinations found from trunk()', vim.log.levels.WARN)
    return
  end

  vim.ui.select(destinations, {
    prompt = 'Rebase ' .. revset .. ' onto:',
    format_item = function(item)
      return item
    end,
  }, function(choice)
    if not choice then
      return
    end
    local dest_id = choice:match '^(%S+)'
    if dest_id then
      run_jj_cmd('rebase', '-r ' .. revset .. ' -d ' .. dest_id)
      run_jj_cmd 'rdev'
      refresh_log()
    end
  end)
end, { refresh = false }) -- refresh handled in callback

actions.undo = function()
  run_jj_cmd('undo', '')
  refresh_log()
end

actions.redo = function()
  run_jj_cmd('redo', '')
  refresh_log()
end

local function nav(direction)
  vim.cmd('normal! 2' .. direction)
  -- Skip preview update if an async job is running
  if has_active_job() then
    return
  end
  local revset = get_revset()
  if not revset then
    return
  end
  local cmd = is_visual() and 'diff' or 'show'
  local output = vim.fn.system(build_jj_cmd(cmd .. ' -r ' .. revset .. ' --git'))
  preview.open(output, cmd, revset, { filetype = 'jujutsu', no_colorize = true })
end

-- Navigate from preview buffer: move cursor in log and update preview
preview_nav = function(direction)
  if not is_win_valid(M.state.win) or not is_buf_valid(M.state.buf) or has_active_job() then
    return
  end

  -- Don't navigate if there's a visual selection (doesn't make sense)
  if M.state.stored_visual_range then
    return
  end

  local preview_id = M.state.preview.change_id
  if not preview_id then
    return
  end

  -- Handle range revsets - use newest for positioning
  local target_id = preview_id:match '::(.+)$' or preview_id

  -- Build list of (line_number, change_id) from log buffer
  local lines = vim.api.nvim_buf_get_lines(M.state.buf, 0, -1, false)
  local commits = {}
  for i, line in ipairs(lines) do
    local line_id = get_change_id_from_line(line)
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
  vim.api.nvim_win_call(M.state.win, function()
    vim.api.nvim_win_set_cursor(M.state.win, { new_commit.line, 0 })
    vim.cmd 'normal! zz'
  end)

  -- Update preview
  local output = vim.fn.system(build_jj_cmd('show -r ' .. new_commit.id .. ' --git'))
  preview.open(output, 'show', new_commit.id, { filetype = 'jujutsu', no_colorize = true })
end

actions.nav_down = function()
  nav 'j'
end
actions.nav_up = function()
  nav 'k'
end

actions.cdescribe = with_change_id(function(id)
  local saved_cursor = is_win_valid(M.state.win)
      and vim.api.nvim_win_get_cursor(M.state.win)
    or nil

  -- Cancel any pending preview updates
  cancel_debounce()

  local buf = vim.api.nvim_create_buf(false, true)
  local height = math.floor(vim.o.lines * 0.5)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - CONST.FLOAT_WIDTH) / 2),
    width = CONST.FLOAT_WIDTH,
    height = height,
    border = 'rounded',
    title = ' cdescribe ' .. id .. ' ',
    title_pos = 'center',
  })

  local cmd = string.format('cd %s && cdescribe %s', vim.fn.shellescape(M.state.cwd), id)
  local job_id = vim.fn.termopen(cmd, {
    on_exit = function()
      vim.schedule(function()
        clear_active_job()
        vim.cmd 'stopinsert'
        if vim.api.nvim_win_is_valid(win) then
          vim.api.nvim_win_close(win, true)
        end
        if is_win_valid(M.state.win) then
          vim.api.nvim_set_current_win(M.state.win)
        end
        refresh_log(saved_cursor)
        if saved_cursor and is_win_valid(M.state.win) then
          pcall(vim.api.nvim_win_set_cursor, M.state.win, saved_cursor)
        end
      end)
    end,
  })

  if job_id > 0 then
    set_active_job(job_id)
  end

  vim.cmd 'startinsert'
end, { refresh = false })

--------------------------------------------------------------------------------
-- 7. Keymaps
--------------------------------------------------------------------------------

local keymap_defs = {
  -- Navigation (2 lines per commit)
  { modes = { 'n' }, key = 'j', action = actions.nav_down },
  { modes = { 'n' }, key = 'k', action = actions.nav_up },
  { modes = { 'n' }, key = '<Down>', action = actions.nav_down },
  { modes = { 'n' }, key = '<Up>', action = actions.nav_up },
  { modes = { 'x' }, key = 'j', action = actions.nav_down },
  { modes = { 'x' }, key = 'k', action = actions.nav_up },
  { modes = { 'x' }, key = '<Down>', action = actions.nav_down },
  { modes = { 'x' }, key = '<Up>', action = actions.nav_up },

  -- Preview actions
  { modes = { 'n', 'x' }, key = '<CR>', action = actions.show },
  { modes = { 'n' }, key = 'D', action = actions.cdescribe },
  { modes = { 'n', 'x' }, key = 'd', action = actions.describe },
  { modes = { 'n', 'x' }, key = 's', action = actions.squash },
  { modes = { 'n', 'x' }, key = 'S', action = actions.squash_into },

  -- Edit actions
  { modes = { 'n' }, key = 'e', action = actions.edit },
  { modes = { 'n' }, key = 'n', action = actions.new },
  { modes = { 'n' }, key = 'N', action = actions.new_current },
  { modes = { 'n', 'x' }, key = 'x', action = actions.abandon },
  { modes = { 'n' }, key = 'b', action = actions.bookmark },
  { modes = { 'n' }, key = 'u', action = actions.undo },
  { modes = { 'n' }, key = 'r', action = actions.redo },
  { modes = { 'n', 'x' }, key = 'R', action = actions.rebase },

  -- UI
  { modes = { 'n', 'x' }, key = '<Tab>', action = preview.toggle_focus },
  { modes = { 'n' }, key = '?', action = show_help },
  { modes = { 'n' }, key = 'q', action = close_flog },
  { modes = { 'n' }, key = '<Esc>', action = close_flog },
}

local function setup_keymaps(buf)
  for _, def in ipairs(keymap_defs) do
    vim.keymap.set(def.modes, def.key, def.action, { buffer = buf, nowait = true })
  end
end

--------------------------------------------------------------------------------
-- 8. Public API & Setup
--------------------------------------------------------------------------------

function M.jujutsu_flog()
  M.state.cwd = vim.fn.getcwd()
  local output = vim.fn.system(build_jj_cmd 'log -r :: --color=always')

  vim.cmd 'tabnew'
  local buf = vim.api.nvim_get_current_buf()
  M.state.buf = buf
  M.state.win = vim.api.nvim_get_current_win()

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(output, '\n'))
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].buflisted = false

  vim.bo[buf].modifiable = true
  safe_colorize()
  vim.bo[buf].modifiable = false

  setup_keymaps(buf)
  setup_dual_cursorline(buf, M.state.win)

  -- Debounced initial show - will be cancelled if user starts an operation quickly
  debounce(function()
    if is_win_valid(M.state.win) and not has_active_job() then
      vim.api.nvim_win_set_cursor(M.state.win, { 1, 0 })
      actions.show()
    end
  end, CONST.CURSOR_RESTORE_DELAY_MS)
end

M.jujutsu_quick_view = M.jujutsu_flog

function M.jujutsu_new()
  local output = vim.fn.system 'jj new'
  local is_success = vim.v.shell_error == 0
  local level = is_success and vim.log.levels.INFO or vim.log.levels.ERROR
  local prefix = is_success and 'New Jujutsu commit created:\n'
    or 'Error creating commit: '
  vim.notify(prefix .. output, level)
end

local function smart_log()
  if is_jujutsu_repo() then
    M.jujutsu_flog()
  else
    vim.cmd 'Flog'
  end
end

function M.setup()
  vim.keymap.set('n', '<leader>jn', M.jujutsu_new, { desc = 'Create new Jujutsu commit' })
  vim.keymap.set('n', '<leader>gl', smart_log, { desc = 'Git/Jujutsu log (smart)' })
end

return M
