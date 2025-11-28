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
}

local function is_win_valid(win)
  return win and vim.api.nvim_win_is_valid(win)
end

local function is_buf_valid(buf)
  return buf and vim.api.nvim_buf_is_valid(buf)
end

local function preview_is_valid()
  return is_win_valid(M.state.preview.win) and is_buf_valid(M.state.preview.buf)
end

--------------------------------------------------------------------------------
-- 3. Utilities
--------------------------------------------------------------------------------

local function safe_colorize()
  if Snacks and Snacks.terminal and Snacks.terminal.colorize then
    Snacks.terminal.colorize()
  end
end

local function strip_ansi(str)
  return str:gsub('\027%[[%d;]*m', '')
end

local function get_change_id_from_line(line)
  local clean = strip_ansi(line)
  -- Match change ID: 8+ lowercase letters/numbers after graph chars (│ ◆ ○ @ ◉ ~)
  local change_id = clean:match '[│◆○@◉~%s]+([a-z][a-z0-9]+)%s'
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
  local lines = vim.api.nvim_buf_get_lines(vim.api.nvim_get_current_buf(), 0, cursor_line, false)
  for i = #lines, 1, -1 do
    local match = lines[i]:match '^diff %-%-git a/(.-) b/'
    if match then
      return match
    end
  end
  return nil
end

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

-- Forward declaration for refresh_log (used in run_jj_with_editor)
local refresh_log

local function run_jj_with_editor(jj_args, title, on_complete)
  local saved_cursor = is_win_valid(M.state.win)
      and vim.api.nvim_win_get_cursor(M.state.win)
    or nil

  local session_dir = vim.fn.tempname()
  vim.fn.mkdir(session_dir, 'p')

  local file_marker = session_dir .. '/jj_file'
  local waiting_marker = session_dir .. '/waiting'
  local editor_script = session_dir .. '/editor.sh'

  vim.fn.writefile({}, waiting_marker)
  vim.fn.writefile({
    '#!/bin/sh',
    'echo "$1" > "' .. file_marker .. '"',
    'while [ -f "' .. waiting_marker .. '" ]; do sleep 0.1; done',
    'exit 0',
  }, editor_script)
  vim.fn.setfperm(editor_script, 'rwx------')

  local cmd = string.format(
    'cd %s && JJ_EDITOR=%s jj %s 2>&1',
    vim.fn.shellescape(M.state.cwd),
    vim.fn.shellescape(editor_script),
    jj_args
  )

  local jj_output = {}
  local job_id = vim.fn.jobstart(cmd, {
    on_stdout = function(_, data)
      vim.list_extend(jj_output, data)
    end,
    on_stderr = function(_, data)
      vim.list_extend(jj_output, data)
    end,
    on_exit = function(_, exit_code)
      vim.fn.delete(session_dir, 'rf')
      local output = table.concat(jj_output, '\n'):gsub('^%s+', ''):gsub('%s+$', '')
      if exit_code == 0 then
        if output ~= '' then
          vim.notify(output, vim.log.levels.INFO)
        end
        refresh_log(saved_cursor)
      elseif output ~= '' and not output:match 'interrupt' then
        vim.notify(output, vim.log.levels.ERROR)
      end
      if on_complete then
        on_complete(exit_code == 0)
      end
    end,
  })

  if job_id <= 0 then
    vim.fn.delete(session_dir, 'rf')
    vim.notify('Failed to start jj', vim.log.levels.ERROR)
    return
  end

  local attempts = 0
  local function check_for_file()
    attempts = attempts + 1
    if vim.fn.filereadable(file_marker) == 1 then
      local lines = vim.fn.readfile(file_marker)
      if #lines > 0 and lines[1] ~= '' then
        local jj_file = lines[1]
        local buf = vim.fn.bufadd(jj_file)
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

        vim.bo[buf].filetype = 'gitcommit'
        vim.wo[win].wrap = true
        vim.wo[win].cursorline = false

        local closed = false
        local function cleanup()
          if closed then
            return
          end
          closed = true
          vim.fn.delete(waiting_marker)
        end

        local function finish_edit()
          closed = true
          vim.api.nvim_buf_call(buf, function()
            vim.cmd 'silent! write!'
          end)
          if saved_cursor and is_win_valid(M.state.win) then
            pcall(vim.api.nvim_win_set_cursor, M.state.win, saved_cursor)
          end
          if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
          end
          vim.defer_fn(function()
            vim.fn.delete(waiting_marker)
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
        return
      end
    end

    if attempts < CONST.EDITOR_POLL_MAX_ATTEMPTS then
      vim.defer_fn(check_for_file, CONST.EDITOR_POLL_INTERVAL_MS)
    else
      vim.fn.jobstop(job_id)
      vim.fn.delete(session_dir, 'rf')
      vim.notify('Timeout waiting for jj', vim.log.levels.ERROR)
    end
  end

  vim.defer_fn(check_for_file, CONST.EDITOR_POLL_INTERVAL_MS)
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
    else
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

  if preview_is_valid() then
    -- Reuse existing preview window
    local current_win = vim.api.nvim_get_current_win()
    vim.api.nvim_set_current_win(M.state.preview.win)

    vim.bo[M.state.preview.buf].filetype = opts.filetype or 'diff'
    vim.bo[M.state.preview.buf].modifiable = true
    vim.api.nvim_buf_set_lines(M.state.preview.buf, 0, -1, false, content_lines)
    if not opts.no_colorize then
      safe_colorize()
    end
    vim.bo[M.state.preview.buf].modifiable = false

    if opts.filetype == 'jujutsu' then
      create_folds_for_diff(M.state.preview.win, content_lines)
    end

    vim.api.nvim_set_current_win(current_win)
  else
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

    -- Preview keymaps (defined inline to avoid forward declaration issues)
    vim.keymap.set('n', 'q', function()
      preview.close()
      if is_win_valid(M.state.win) then
        vim.api.nvim_set_current_win(M.state.win)
      end
    end, { buffer = buf, nowait = true })

    vim.keymap.set('n', 'O', function()
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

      local old_content = vim.fn.system(
        build_jj_cmd('file show -r ' .. cid .. '- ' .. vim.fn.shellescape(file_path))
      )
      local new_content = vim.fn.system(
        build_jj_cmd('file show -r ' .. cid .. ' ' .. vim.fn.shellescape(file_path))
      )

      vim.cmd 'tabnew'
      local old_buf = vim.api.nvim_get_current_buf()
      vim.api.nvim_buf_set_lines(old_buf, 0, -1, false, vim.split(old_content, '\n'))
      vim.bo[old_buf].buftype = 'nofile'
      vim.bo[old_buf].bufhidden = 'wipe'
      vim.bo[old_buf].buflisted = false
      vim.api.nvim_buf_set_name(old_buf, file_path .. ' (old)')

      local ft = vim.filetype.match { filename = file_path }
      if ft then
        vim.bo[old_buf].filetype = ft
      end
      vim.cmd 'diffthis'

      vim.cmd 'rightbelow vsplit'
      local new_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_win_set_buf(0, new_buf)
      vim.api.nvim_buf_set_lines(new_buf, 0, -1, false, vim.split(new_content, '\n'))
      vim.bo[new_buf].buftype = 'nofile'
      vim.bo[new_buf].bufhidden = 'wipe'
      vim.bo[new_buf].buflisted = false
      vim.api.nvim_buf_set_name(new_buf, file_path .. ' (new)')

      if ft then
        vim.bo[new_buf].filetype = ft
      end
      vim.cmd 'diffthis'

      local function close_diff_tab()
        vim.cmd 'diffoff!'
        vim.cmd 'tabclose'
      end
      vim.keymap.set('n', 'q', close_diff_tab, { buffer = old_buf, nowait = true })
      vim.keymap.set('n', 'q', close_diff_tab, { buffer = new_buf, nowait = true })
    end, { buffer = buf, nowait = true })

    vim.keymap.set('n', '<CR>', function()
      vim.api.nvim_feedkeys('O', 'n', false)
    end, { buffer = buf, nowait = true })

    vim.keymap.set('n', '<Tab>', preview.toggle_focus, { buffer = buf, nowait = true })
  end

  M.state.preview.type = preview_type
  M.state.preview.change_id = change_id

  -- Return focus to log window
  if is_win_valid(M.state.win) then
    vim.api.nvim_set_current_win(M.state.win)
    if log_cursor then
      vim.api.nvim_win_set_cursor(M.state.win, log_cursor)
    end
  end

  return M.state.preview.buf
end

local function show_help()
  local help_lines = {
    '  Jujutsu Flog - Keybindings',
    '  ──────────────────────────',
    '  Preview (toggle, reuses pane):',
    '  <CR>  show      - Show commit details',
    '  D     cdescribe - AI-generate description (interactive)',
    '  d     describe  - Edit description (<CR> save, q cancel)',
    '  s     squash    - Squash commit (visual: squash range)',
    '  O/<CR> split    - Open file diff side-by-side (in preview)',
    '',
    '  Actions:',
    '  e     edit     - Edit (checkout) commit',
    '  n     new      - New commit after this one',
    '  N     new @    - New commit after current',
    '  x     abandon  - Abandon commit (confirm)',
    '  b     bookmark - Set bookmark on commit',
    '  u     undo     - Undo last operation',
    '  r     redo     - Redo last undo',
    '',
    '  Navigation:',
    '  j/k   move     - Move by commit (2 lines)',
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

--- Execute an action that requires a change ID under cursor
---@param action_fn function(change_id: string)
---@param opts? { refresh?: boolean }
---@return function
local function with_change_id(action_fn, opts)
  opts = opts or {}
  return function()
    local change_id = get_change_id_under_cursor()
    if not change_id then
      vim.notify('No change ID found on this line', vim.log.levels.WARN)
      return
    end
    action_fn(change_id)
    if opts.refresh ~= false then
      refresh_log()
    end
  end
end

-- Define refresh_log (uses existing buffer, keymaps already attached)
refresh_log = function(cursor_pos)
  if not is_win_valid(M.state.win) or not is_buf_valid(M.state.buf) then
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

  -- Deferred restore as final backup
  vim.defer_fn(function()
    if is_win_valid(M.state.win) then
      pcall(vim.api.nvim_win_set_cursor, M.state.win, { row, col })
    end
  end, CONST.CURSOR_RESTORE_DELAY_MS)
end

local function close_flog()
  preview.close()
  if is_buf_valid(M.state.buf) then
    vim.cmd 'tabclose'
  end
  M.state.win = nil
  M.state.buf = nil
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

  local output = vim.fn.system(build_jj_cmd('show -r ' .. id .. ' --git'))
  preview.open(output, 'show', id, { filetype = 'jujutsu', no_colorize = true })

  vim.defer_fn(function()
    if is_win_valid(win) then
      vim.api.nvim_win_set_cursor(win, cursor)
    end
  end, 10)
end, { refresh = false })

actions.squash = function()
  local mode = vim.fn.mode()

  if mode == 'v' or mode == 'V' or mode == '\22' then
    -- Multi-commit squash from visual selection
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
      vim.notify('No change IDs found in selection', vim.log.levels.WARN)
      return
    end

    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, false, true), 'nx', false)

    vim.schedule(function()
      if #change_ids == 1 then
        run_jj_with_editor('squash -r ' .. change_ids[1], ' Squash ' .. change_ids[1] .. ' ')
        return
      end

      local newest = change_ids[1]
      local oldest = change_ids[#change_ids]
      local cmd = string.format('squash -f %s::%s -t %s', oldest, newest, oldest)
      run_jj_with_editor(cmd, ' Squash ' .. oldest .. '::' .. newest .. ' ')
    end)
  else
    -- Single commit squash
    local id = get_change_id_under_cursor()
    if not id then
      vim.notify('No change ID found on this line', vim.log.levels.WARN)
      return
    end
    run_jj_with_editor('squash -r ' .. id, ' Squash ' .. id .. ' ')
  end
end

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

actions.undo = function()
  run_jj_cmd('undo', '')
  refresh_log()
end

actions.redo = function()
  run_jj_cmd('redo', '')
  refresh_log()
end

actions.nav_down = function()
  vim.cmd 'normal! 2j'
  actions.show()
end

actions.nav_up = function()
  vim.cmd 'normal! 2k'
  actions.show()
end

actions.cdescribe = with_change_id(function(id)
  local saved_cursor = is_win_valid(M.state.win)
      and vim.api.nvim_win_get_cursor(M.state.win)
    or nil

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
  vim.fn.termopen(cmd, {
    on_exit = function()
      vim.schedule(function()
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
  { modes = { 'x' }, key = 'j', action = '2j' },
  { modes = { 'x' }, key = 'k', action = '2k' },
  { modes = { 'x' }, key = '<Down>', action = '2j' },
  { modes = { 'x' }, key = '<Up>', action = '2k' },

  -- Preview actions
  { modes = { 'n', 'x' }, key = '<CR>', action = actions.show },
  { modes = { 'n' }, key = 'D', action = actions.cdescribe },
  { modes = { 'n' }, key = 'd', action = actions.describe },
  { modes = { 'n', 'x' }, key = 's', action = actions.squash },

  -- Edit actions
  { modes = { 'n' }, key = 'e', action = actions.edit },
  { modes = { 'n' }, key = 'n', action = actions.new },
  { modes = { 'n' }, key = 'N', action = actions.new_current },
  { modes = { 'n' }, key = 'x', action = actions.abandon },
  { modes = { 'n' }, key = 'b', action = actions.bookmark },
  { modes = { 'n' }, key = 'u', action = actions.undo },
  { modes = { 'n' }, key = 'r', action = actions.redo },

  -- UI
  { modes = { 'n' }, key = '<Tab>', action = preview.toggle_focus },
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

  vim.defer_fn(function()
    if is_win_valid(M.state.win) then
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
  local prefix = is_success and 'New Jujutsu commit created:\n' or 'Error creating commit: '
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
