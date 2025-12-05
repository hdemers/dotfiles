-- vim: ts=2 sts=2 sw=2 et
-- jujutsu/init.lua - A flog-inspired Jujutsu log viewer for Neovim

local M = {}

--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------

M.CONST = {
  CHANGE_ID_LENGTH = 8,
  LINES_PER_COMMIT = 2,
  EDITOR_POLL_INTERVAL_MS = 100,
  EDITOR_POLL_MAX_ATTEMPTS = 50,
  CURSOR_RESTORE_DELAY_MS = 100,
  FLOAT_WIDTH = 100,
  HELP_WIDTH = 63,
}

--------------------------------------------------------------------------------
-- State Management
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

--------------------------------------------------------------------------------
-- Utilities namespace (exposed for other modules)
--------------------------------------------------------------------------------

M.utils = {}

local function is_win_valid(win)
  return win and vim.api.nvim_win_is_valid(win)
end

local function is_buf_valid(buf)
  return buf and vim.api.nvim_buf_is_valid(buf)
end

local function state_is_valid()
  return is_win_valid(M.state.win) and is_buf_valid(M.state.buf)
end

-- Cancel any pending debounced operation
function M.utils.cancel_debounce()
  if M.state.debounce_timer then
    M.state.debounce_timer:stop()
    M.state.debounce_timer:close()
    M.state.debounce_timer = nil
  end
end

-- Debounce a function call (cancels previous pending call)
local function debounce(fn, delay_ms)
  M.utils.cancel_debounce()
  M.state.debounce_timer = vim.uv.new_timer()
  M.state.debounce_timer:start(
    delay_ms,
    0,
    vim.schedule_wrap(function()
      M.utils.cancel_debounce()
      fn()
    end)
  )
end

-- Track and cancel active async jj jobs
function M.utils.set_active_job(job_id)
  -- Cancel previous job if still running
  if M.state.active_job and vim.fn.jobwait({ M.state.active_job }, 0)[1] == -1 then
    vim.fn.jobstop(M.state.active_job)
  end
  M.state.active_job = job_id
end

function M.utils.clear_active_job()
  M.state.active_job = nil
end

function M.utils.has_active_job()
  return M.state.active_job and vim.fn.jobwait({ M.state.active_job }, 0)[1] == -1
end

-- Colorization helper
local function safe_colorize()
  if Snacks and Snacks.terminal and Snacks.terminal.colorize then
    local saved_listchars = vim.opt.listchars:get()
    Snacks.terminal.colorize()
    vim.opt.listchars = saved_listchars
  end
end

-- Strip ANSI escape codes
local function strip_ansi(str)
  return str:gsub('\027%[[%d;]*m', '')
end

function M.utils.get_change_id_from_line(line)
  local clean = strip_ansi(line)
  -- Require a commit marker (◆◇○@◉×~) to distinguish commit lines from description continuations
  -- Description lines only have │ and spaces, so they won't match
  local change_id =
    clean:match '[│%s]*[◆◇○@◉×~][│%s]*([a-z][a-z0-9]+)%s+[a-z0-9]+'
  if change_id and #change_id >= M.CONST.CHANGE_ID_LENGTH then
    return change_id:sub(1, M.CONST.CHANGE_ID_LENGTH)
  end
  return nil
end

function M.utils.get_change_id_under_cursor()
  return M.utils.get_change_id_from_line(vim.api.nvim_get_current_line())
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

function M.utils.get_diff_file_at_cursor()
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
-- Command Execution Layer
--------------------------------------------------------------------------------

function M.utils.build_jj_cmd(args, cwd)
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

function M.utils.run_jj_cmd(cmd, change_id, opts)
  opts = opts or {}
  local args = change_id and (cmd .. ' ' .. change_id) or cmd
  local full_cmd = M.utils.build_jj_cmd(args)
  local output = vim.fn.system(full_cmd)
  local success = vim.v.shell_error == 0

  if opts.notify ~= false then
    local level = success and vim.log.levels.INFO or vim.log.levels.ERROR
    vim.notify(output, level)
  end

  return output, success
end

function M.utils.get_revisions(opts)
  opts = opts or {}
  local revset = opts.revset or 'trunk()::'
  local template = opts.template or DEFAULT_REVISION_TEMPLATE

  local cmd = 'log -r '
    .. vim.fn.shellescape(revset)
    .. ' --no-graph --template '
    .. vim.fn.shellescape(template .. ' ++ "\\n"')
  local output, success = M.utils.run_jj_cmd(cmd, nil, { notify = false })
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

--------------------------------------------------------------------------------
-- Editor Session Management
--------------------------------------------------------------------------------

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
    col = math.floor((vim.o.columns - M.CONST.FLOAT_WIDTH) / 2),
    width = M.CONST.FLOAT_WIDTH,
    height = height,
    border = 'rounded',
    title = title .. '│ <CR> save │ q cancel ',
    title_pos = 'center',
  })

  vim.bo[buf].filetype = 'jjdescription'
  vim.wo[win].wrap = true
  vim.wo[win].cursorline = false

  local augroup = vim.api.nvim_create_augroup('JujutsuEditor', { clear = true })
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
    end, M.CONST.CURSOR_RESTORE_DELAY_MS)
  end

  local function cancel_edit()
    vim.fn.jobstop(job_id)
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    cleanup()
  end

  vim.api.nvim_create_autocmd('WinClosed', {
    group = augroup,
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

function M.utils.run_jj_with_editor(jj_args, title, on_complete)
  local session = create_editor_session(jj_args)

  -- Cancel any pending preview updates
  M.utils.cancel_debounce()

  local jj_output = {}
  local job_id = vim.fn.jobstart(session.cmd, {
    on_stdout = function(_, data)
      vim.list_extend(jj_output, data)
    end,
    on_stderr = function(_, data)
      vim.list_extend(jj_output, data)
    end,
    on_exit = function(_, exit_code)
      M.utils.clear_active_job()
      vim.fn.delete(session.dir, 'rf')
      local output = table.concat(jj_output, '\n'):gsub('^%s+', ''):gsub('%s+$', '')
      if exit_code == 0 then
        if output ~= '' then
          vim.notify(output, vim.log.levels.INFO)
        end
        M.utils.refresh_log(session.saved_cursor)
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

  M.utils.set_active_job(job_id)

  local attempts = 0
  local function poll_for_editor()
    attempts = attempts + 1
    if vim.fn.filereadable(session.file_marker) == 1 then
      if open_editor_float(session, job_id, title) then
        return
      end
    end

    if attempts < M.CONST.EDITOR_POLL_MAX_ATTEMPTS then
      vim.defer_fn(poll_for_editor, M.CONST.EDITOR_POLL_INTERVAL_MS)
    else
      vim.fn.jobstop(job_id)
      vim.fn.delete(session.dir, 'rf')
      vim.notify('Timeout waiting for jj', vim.log.levels.ERROR)
    end
  end

  vim.defer_fn(poll_for_editor, M.CONST.EDITOR_POLL_INTERVAL_MS)
end

--------------------------------------------------------------------------------
-- Log refresh
--------------------------------------------------------------------------------

-- Refresh preview with revision under cursor (called after log refresh)
local function refresh_preview_after_log()
  -- Early exit if plugin was closed (cwd is nil when fully closed)
  if not M.state.cwd then
    return
  end

  local preview = require 'jujutsu.preview'

  if
    not is_win_valid(M.state.preview.win)
    or not M.state.preview.change_id
    or M.utils.has_active_job()
  then
    return
  end

  vim.schedule(function()
    -- Re-check cwd since we're in a scheduled callback
    if
      not M.state.cwd
      or not is_win_valid(M.state.preview.win)
      or not is_win_valid(M.state.win)
      or M.utils.has_active_job()
    then
      return
    end

    -- Ensure we're in the log window
    local prev_win = vim.api.nvim_get_current_win()
    vim.api.nvim_set_current_win(M.state.win)

    local id = M.utils.get_change_id_under_cursor()
    if id then
      local preview_type = M.state.preview.type or 'show'
      local cmd = preview_type == 'diff' and ('diff -r ' .. id .. ' --git')
        or ('show -r ' .. id .. ' --git')
      local output = vim.fn.system(M.utils.build_jj_cmd(cmd))
      M.state.preview.change_id = nil -- force update
      preview.open(output, preview_type, id, { filetype = 'jujutsu', no_colorize = true })
    end

    -- Restore previous window if different
    if prev_win ~= M.state.win and vim.api.nvim_win_is_valid(prev_win) then
      vim.api.nvim_set_current_win(prev_win)
    end
  end)
end

function M.utils.refresh_log(cursor_pos)
  -- Early exit if plugin was closed (cwd is nil when fully closed)
  if not M.state.cwd or not state_is_valid() then
    return
  end

  cursor_pos = cursor_pos or vim.api.nvim_win_get_cursor(M.state.win)

  local output = vim.fn.system(M.utils.build_jj_cmd 'log -r :: --color=always')
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

  -- Debounced preview refresh
  debounce(function()
    if M.state.cwd and is_win_valid(M.state.win) then
      pcall(vim.api.nvim_win_set_cursor, M.state.win, { row, col })
      refresh_preview_after_log()
    end
  end, M.CONST.CURSOR_RESTORE_DELAY_MS)
end

--------------------------------------------------------------------------------
-- Close flog
--------------------------------------------------------------------------------

local function close_flog()
  local preview = require 'jujutsu.preview'

  M.utils.cancel_debounce()
  -- Stop any active job
  if M.state.active_job then
    pcall(vim.fn.jobstop, M.state.active_job)
  end
  preview.close()
  if is_buf_valid(M.state.buf) then
    vim.cmd 'tabclose'
  end
  M.state.win = nil
  M.state.buf = nil
  M.state.active_job = nil
  M.state.cwd = nil -- Mark as fully closed
end

M.close = close_flog

--------------------------------------------------------------------------------
-- Keymaps
--------------------------------------------------------------------------------

local function setup_keymaps(buf)
  local actions = require 'jujutsu.actions'
  local preview = require 'jujutsu.preview'

  -- Navigation (2 lines per commit) - table-driven for DRYness
  local nav_keys = {
    { key = 'j', action = actions.nav_down },
    { key = 'k', action = actions.nav_up },
    { key = '<Down>', action = actions.nav_down },
    { key = '<Up>', action = actions.nav_up },
  }
  for _, def in ipairs(nav_keys) do
    vim.keymap.set({ 'n', 'x' }, def.key, def.action, { buffer = buf, nowait = true })
  end

  -- Preview actions
  vim.keymap.set({ 'n', 'x' }, '<CR>', actions.show, { buffer = buf, nowait = true })
  vim.keymap.set('n', 'D', actions.cdescribe, { buffer = buf, nowait = true })
  vim.keymap.set({ 'n', 'x' }, 'd', actions.describe, { buffer = buf, nowait = true })
  vim.keymap.set({ 'n', 'x' }, 's', actions.squash, { buffer = buf, nowait = true })
  vim.keymap.set({ 'n', 'x' }, 'S', actions.squash_into, { buffer = buf, nowait = true })

  -- Edit actions
  vim.keymap.set('n', 'e', actions.edit, { buffer = buf, nowait = true })
  vim.keymap.set('n', 'n', actions.new, { buffer = buf, nowait = true })
  vim.keymap.set('n', 'N', actions.new_current, { buffer = buf, nowait = true })
  vim.keymap.set({ 'n', 'x' }, 'x', actions.abandon, { buffer = buf, nowait = true })
  vim.keymap.set('n', 'b', actions.bookmark, { buffer = buf, nowait = true })
  vim.keymap.set('n', 'B', actions.move_bookmark, { buffer = buf, nowait = true })
  vim.keymap.set('n', 'u', actions.undo, { buffer = buf, nowait = true })
  vim.keymap.set('n', 'U', actions.redo, { buffer = buf, nowait = true })
  vim.keymap.set({ 'n', 'x' }, 'r', actions.rebase, { buffer = buf, nowait = true })
  vim.keymap.set('n', 'w', actions.rebase_before_parent, { buffer = buf, nowait = true })
  vim.keymap.set('n', 'p', actions.push, { buffer = buf, nowait = true })
  vim.keymap.set('n', 'P', actions.push_bookmark, { buffer = buf, nowait = true })

  -- UI
  vim.keymap.set(
    { 'n', 'x' },
    '<CR>',
    preview.toggle_focus,
    { buffer = buf, nowait = true }
  )
  vim.keymap.set('n', 'g?', preview.show_help, { buffer = buf, nowait = true })
  vim.keymap.set('n', 'gq', close_flog, { buffer = buf, nowait = true })

  -- Clear snacks.nvim's q mapping from colorize()
  pcall(vim.keymap.del, 'n', 'q', { buffer = buf })
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

function M.jujutsu_flog()
  local preview = require 'jujutsu.preview'
  local actions = require 'jujutsu.actions'

  -- Clean up any existing JJ-log buffer BEFORE setting state
  -- (deleting triggers BufWipeout which clears state)
  local existing = vim.fn.bufnr 'JJ-log'
  if existing ~= -1 then
    vim.api.nvim_buf_delete(existing, { force = true })
  end

  M.state.cwd = vim.fn.getcwd()

  local output = vim.fn.system(M.utils.build_jj_cmd 'log -r :: --color=always')

  vim.cmd 'tabnew'
  local buf = vim.api.nvim_get_current_buf()
  M.state.buf = buf
  M.state.win = vim.api.nvim_get_current_win()

  vim.api.nvim_buf_set_name(buf, 'JJ-log')
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].buflisted = false

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(output, '\n'))
  vim.bo[buf].modifiable = true
  safe_colorize()
  vim.bo[buf].modifiable = false

  setup_keymaps(buf)
  preview.setup_dual_cursorline(buf, M.state.win)

  -- Intercept :tabclose to use proper cleanup (prevents crashes)
  -- Use abbreviation since we can't override built-in commands
  vim.cmd.cnoreabbrev '<buffer> tabclose JJClose'
  vim.api.nvim_buf_create_user_command(buf, 'JJClose', function()
    close_flog()
  end, { bang = true })
  -- Override <leader>w if user has it mapped to :tabclose
  vim.keymap.set('n', '<leader>w', close_flog, { buffer = buf, nowait = true })

  -- Cleanup when buffer is wiped (e.g., by tabclose)
  vim.api.nvim_create_autocmd('BufWipeout', {
    buffer = buf,
    once = true,
    callback = function()
      M.utils.cancel_debounce()
      -- Stop any active job to prevent on_exit callback from firing after cleanup
      if M.state.active_job then
        pcall(vim.fn.jobstop, M.state.active_job)
      end
      -- Don't call preview.close() here - Neovim is already closing everything
      -- Just clear state to prevent callbacks from accessing invalid handles
      M.state.preview = { buf = nil, win = nil, type = nil, change_id = nil }
      M.state.win = nil
      M.state.buf = nil
      M.state.active_job = nil
      M.state.cwd = nil -- Mark as fully closed
    end,
  })

  -- Debounced initial show
  debounce(function()
    if M.state.cwd and is_win_valid(M.state.win) and not M.utils.has_active_job() then
      vim.api.nvim_win_set_cursor(M.state.win, { 1, 0 })
      actions.show()
    end
  end, M.CONST.CURSOR_RESTORE_DELAY_MS)
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

--------------------------------------------------------------------------------
-- Setup
--------------------------------------------------------------------------------

function M.setup()
  -- Global keymaps
  vim.keymap.set('n', '<leader>jn', M.jujutsu_new, { desc = 'Create new Jujutsu commit' })
  vim.keymap.set('n', '<leader>gl', smart_log, { desc = 'Git/Jujutsu log (smart)' })

  -- User commands
  vim.api.nvim_create_user_command('JujutsuLog', M.jujutsu_flog, {})
  vim.api.nvim_create_user_command('JujutsuNew', M.jujutsu_new, {})
end

return M
