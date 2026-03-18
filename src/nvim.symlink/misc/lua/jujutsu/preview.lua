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
-- Syntax highlighting for preview buffer
--------------------------------------------------------------------------------

local preview_hl_ns = vim.api.nvim_create_namespace 'jujutsu_preview'

-- Define fg-only highlight groups (default = true lets colorschemes override them)
vim.api.nvim_set_hl(0, 'JJFileAdded', { link = 'String', default = true })
vim.api.nvim_set_hl(
  0,
  'JJFileDeleted',
  { link = 'Error', default = true, strikethrough = true }
)
vim.api.nvim_set_hl(0, 'JJFileModified', { link = 'Type', default = true })
vim.api.nvim_set_hl(0, 'JJConflictHeader', { link = 'DiagnosticError', default = true })
vim.api.nvim_set_hl(0, 'JJConflictFile', { link = 'DiagnosticWarn', default = true })
vim.api.nvim_set_hl(0, 'JJHeaderKey', { link = 'Normal', default = true })
vim.api.nvim_set_hl(0, 'JJCommitId', { link = 'Function', default = true })
vim.api.nvim_set_hl(0, 'JJChangeId', { link = 'Conditional', default = true })
vim.api.nvim_set_hl(0, 'JJAuthorName', { link = 'Constant', default = true })
vim.api.nvim_set_hl(0, 'JJAuthorEmail', { link = 'WarningMsg', default = true })
vim.api.nvim_set_hl(0, 'JJTimestamp', { link = 'Operator', default = true })
vim.api.nvim_set_hl(0, 'JJBookmark', { link = 'JJChangeId', default = true })

-- Log view highlight groups
vim.api.nvim_set_hl(0, 'JJChangeIdDim', { link = 'LineNr', default = true })
vim.api.nvim_set_hl(0, 'JJCommitId', { link = 'Function', default = true })
vim.api.nvim_set_hl(0, 'JJCommitIdDim', { link = 'LineNr', default = true })
vim.api.nvim_set_hl(0, 'JJGraphLine', { link = 'Normal', default = true })
vim.api.nvim_set_hl(0, 'JJWorkingCopy', { link = 'DiagnosticOk', default = true })
vim.api.nvim_set_hl(0, 'JJTrunk', { link = 'String', default = true })
vim.api.nvim_set_hl(0, 'JJImmutable', { link = 'PreProc', default = true })
vim.api.nvim_set_hl(0, 'JJDev', { link = 'DiagnosticWarn', default = true })
vim.api.nvim_set_hl(0, 'JJMutable', { link = 'Normal', default = true })
vim.api.nvim_set_hl(0, 'JJAbandoned', { link = 'Error', default = true })
vim.api.nvim_set_hl(0, 'JJElided', { link = 'Comment', default = true })
vim.api.nvim_set_hl(0, 'JJDescription', { link = 'Normal', default = true })

-- All builtin_log_detailed header lines have their colon aligned at byte 9 (0-indexed).
-- "Commit ID: ..." / "Change ID: ..." / "Author   : ..." / "Committer: ..."
-- nvim_buf_add_highlight uses 0-indexed lines and byte columns (col_end is exclusive).
-- Lua string:find() returns 1-indexed positions; the Lua 1-indexed position of a char
-- doubles as the 0-indexed exclusive end for that char, which we exploit below.

local function hl(buf, group, lnum, col_start, col_end)
  vim.api.nvim_buf_add_highlight(buf, preview_hl_ns, group, lnum, col_start, col_end)
end

-- Highlights "Author   : Name <email> (timestamp)" with per-part colors.
local function highlight_person(buf, lnum, line, colon)
  -- colon: 1-indexed Lua position of ':', also the 0-indexed exclusive end for key
  hl(buf, 'JJHeaderKey', lnum, 0, colon)
  local value_start = colon + 1 -- 0-indexed byte: skip space after colon
  local lt = line:find('<', 1, true)
  local gt = line:find('>', lt or 1, true)
  if lt and gt then
    -- Name: from value_start up to (but not including) the space before '<'
    local raw = line:sub(value_start + 1, lt - 1) -- Lua 1-indexed slice
    local name = raw:match '^(.-)%s*$' -- trim trailing whitespace
    if #name > 0 then
      hl(buf, 'JJAuthorName', lnum, value_start, value_start + #name)
    end
    -- Email: '<' through '>' inclusive
    hl(buf, 'JJAuthorEmail', lnum, lt - 1, gt)
    -- Timestamp: everything after '>'
    if gt < #line then
      hl(buf, 'JJTimestamp', lnum, gt, -1)
    end
  else
    hl(buf, 'JJAuthorName', lnum, value_start, -1)
  end
end

local function apply_preview_highlights(buf, lines)
  vim.api.nvim_buf_clear_namespace(buf, preview_hl_ns, 0, -1)
  local in_conflicts = false
  for i, line in ipairs(lines) do
    local lnum = i - 1
    local colon = line:find ':%s' -- colon followed by space = header separator
    if colon and line:match '^Commit%s+ID%s*:' then
      hl(buf, 'JJHeaderKey', lnum, 0, colon)
      hl(buf, 'JJCommitId', lnum, colon + 1, -1)
    elseif colon and line:match '^Change%s+ID%s*:' then
      hl(buf, 'JJHeaderKey', lnum, 0, colon)
      hl(buf, 'JJChangeId', lnum, colon + 1, -1)
    elseif colon and line:match '^Bookmarks%s*:' then
      hl(buf, 'JJHeaderKey', lnum, 0, colon)
      -- Highlight each bookmark name individually
      local pos = colon + 2 -- Lua 1-indexed: skip colon + space
      while pos <= #line do
        local s, e = line:find('%S+', pos)
        if not s then
          break
        end
        hl(buf, 'JJBookmark', lnum, s - 1, e) -- s-1: 0-indexed start; e: 0-indexed exclusive end
        pos = e + 1
      end
    elseif colon and line:match '^Author%s*:' then
      highlight_person(buf, lnum, line, colon)
    elseif colon and line:match '^Committer%s*:' then
      highlight_person(buf, lnum, line, colon)
    elseif line:match '^M ' or line:match '^R ' then
      hl(buf, 'JJFileModified', lnum, 0, -1)
    elseif line:match '^A ' then
      hl(buf, 'JJFileAdded', lnum, 0, -1)
    elseif line:match '^D ' then
      hl(buf, 'JJFileDeleted', lnum, 0, -1)
    elseif line == 'Conflicts:' then
      hl(buf, 'JJConflictHeader', lnum, 0, -1)
      in_conflicts = true
    elseif in_conflicts and line:match '%S' then
      hl(buf, 'JJConflictFile', lnum, 0, -1)
    end
  end
end

--------------------------------------------------------------------------------
-- Cursorline management
--------------------------------------------------------------------------------

function M.setup_dual_cursorline(buf, win)
  local augroup = vim.api.nvim_create_augroup('JujutsuCursorline', { clear = true })

  vim.api.nvim_create_autocmd({ 'CursorMoved', 'ModeChanged', 'WinEnter', 'WinLeave' }, {
    group = augroup,
    buffer = buf,
    callback = function()
      if not is_buf_valid(buf) or not is_win_valid(win) then
        return true
      end

      local state = get_state()
      vim.api.nvim_buf_clear_namespace(buf, cursorline_ns, 0, -1)

      -- If we are not currently in the main log window, do not draw the normal cursorline,
      -- but DO draw the stored visual range if it exists so we know what was selected.
      if vim.api.nvim_get_current_win() ~= win then
        if state.stored_visual_range then
          local start_line = state.stored_visual_range[1]
          local end_line = state.stored_visual_range[2]

          for line = start_line, end_line do
            vim.api.nvim_buf_set_extmark(buf, cursorline_ns, line - 1, 0, {
              line_hl_group = 'Visual',
            })
          end
          local line_count = vim.api.nvim_buf_line_count(buf)
          if end_line < line_count then
            vim.api.nvim_buf_set_extmark(buf, cursorline_ns, end_line, 0, {
              line_hl_group = 'Visual',
            })
          end
        else
          -- Still draw cursorline at log cursor position when focus is in preview
          local ok, cursor = pcall(vim.api.nvim_win_get_cursor, win)
          if ok then
            local cursor_line = cursor[1]
            local line_count = vim.api.nvim_buf_line_count(buf)
            vim.api.nvim_buf_set_extmark(buf, cursorline_ns, cursor_line - 1, 0, {
              line_hl_group = 'CursorLine',
            })
            if cursor_line < line_count then
              vim.api.nvim_buf_set_extmark(buf, cursorline_ns, cursor_line, 0, {
                line_hl_group = 'CursorLine',
              })
            end
          end
        end
        return
      end

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
        -- Constrain cursor to lines with change IDs
        local utils = get_utils()
        local line_content =
          vim.api.nvim_buf_get_lines(buf, cursor_line - 1, cursor_line, false)[1]
        if line_content and not utils.get_change_id_from_line(line_content) then
          -- If current line has no ID, scan backwards to find one
          local target_line = cursor_line - 1
          while target_line >= 1 do
            local prev_content =
              vim.api.nvim_buf_get_lines(buf, target_line - 1, target_line, false)[1]
            if prev_content and utils.get_change_id_from_line(prev_content) then
              pcall(vim.api.nvim_win_set_cursor, win, { target_line, 4 })
              cursor_line = target_line
              break
            end
            target_line = target_line - 1
          end
        end

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
-- Side-by-side diff
--------------------------------------------------------------------------------

function M.open_file_history()
  local state = get_state()
  local utils = get_utils()
  local file_path = utils.get_diff_file_at_cursor()
  if not file_path then
    vim.notify('No file found at cursor position', vim.log.levels.WARN)
    return
  end
  local cid = state.preview.change_id
  require('jujutsu.init').jujutsu_file_history(file_path, cid)
end

function M.view_file_at_revision()
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

  -- Handle range revsets - use newest for viewing
  local target_id = cid:match '^[^:]+::(.+)$' or cid

  local content = vim.fn.system(
    utils.build_jj_cmd('file show -r ' .. target_id .. ' ' .. vim.fn.shellescape(file_path))
  )
  if vim.v.shell_error ~= 0 then
    vim.notify('Failed to load file content', vim.log.levels.ERROR)
    return
  end

  local ft = vim.filetype.match { filename = file_path }

  vim.cmd 'tabnew'
  local buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(content, '\n'))
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].buflisted = false
  vim.api.nvim_buf_set_name(buf, file_path .. ' (' .. target_id .. ')')
  if ft then
    vim.bo[buf].filetype = ft
  end

  vim.keymap.set('n', 'gq', function()
    vim.cmd 'tabclose'
  end, { buffer = buf, nowait = true })
  vim.bo[buf].modifiable = false
end

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
  vim.keymap.set('n', 'H', M.open_file_history, { buffer = buf, nowait = true })
  vim.keymap.set('n', 'v', M.view_file_at_revision, { buffer = buf, nowait = true })
  vim.keymap.set('n', '<leader>e', M.toggle_focus, { buffer = buf, nowait = true })

  -- Navigate revisions from preview (Tab/Shift-Tab)
  vim.keymap.set('n', '<Tab>', function()
    preview_nav 'j'
  end, { buffer = buf, nowait = true })
  vim.keymap.set('n', '<S-Tab>', function()
    preview_nav 'k'
  end, { buffer = buf, nowait = true })

  -- G goes to last non-empty line (terminal buffers have many trailing empty rows)
  vim.keymap.set('n', 'G', function()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    for i = #lines, 1, -1 do
      if vim.trim(lines[i]) ~= '' then
        vim.api.nvim_win_set_cursor(0, { i, 0 })
        return
      end
    end
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

  -- Early exit if plugin was closed
  if not state.cwd then
    return nil
  end

  -- Same content already showing? Do nothing
  if
    preview_is_valid()
    and state.preview.type == preview_type
    and state.preview.change_id == change_id
  then
    return state.preview.buf
  end

  local content_lines = vim.split(content, '\n')

  if preview_is_valid() then
    -- Reuse existing buffer — update content in place (no terminal, no swapping)
    local buf = state.preview.buf
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, content_lines)
    apply_preview_highlights(buf, content_lines)
    vim.bo[buf].modifiable = false
  else
    -- Create new preview window and buffer
    local log_cursor = is_win_valid(state.win) and vim.api.nvim_win_get_cursor(state.win)
      or nil

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

    -- Window display options (no line numbers, no sign column)
    vim.api.nvim_win_call(win, function()
      vim.wo.number = false
      vim.wo.relativenumber = false
      vim.wo.statuscolumn = ''
      vim.wo.signcolumn = 'no'
      vim.wo.cursorline = true
    end)

    local augroup =
      vim.api.nvim_create_augroup('JJPreviewCursorline_' .. buf, { clear = true })
    vim.api.nvim_create_autocmd({ 'WinEnter', 'BufEnter' }, {
      group = augroup,
      buffer = buf,
      callback = function()
        vim.wo.cursorline = true
      end,
    })
    vim.api.nvim_create_autocmd({ 'WinLeave', 'BufLeave' }, {
      group = augroup,
      buffer = buf,
      callback = function()
        vim.wo.cursorline = false
      end,
    })

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, content_lines)
    apply_preview_highlights(buf, content_lines)
    vim.bo[buf].modifiable = false

    setup_preview_keymaps(buf)

    -- Return focus to log window
    if is_win_valid(state.win) then
      vim.api.nvim_set_current_win(state.win)
      if log_cursor then
        vim.api.nvim_win_set_cursor(state.win, log_cursor)
      end
    end
  end

  state.preview.type = preview_type
  state.preview.change_id = change_id

  return state.preview.buf
end

-- Initialize the async preview event listener
local function setup_preview_event_listener()
  local augroup = vim.api.nvim_create_augroup('JujutsuPreviewListener', { clear = true })

  vim.api.nvim_create_autocmd('User', {
    group = augroup,
    pattern = 'JujutsuRevisionSelected',
    callback = function(args)
      local data = args.data
      if not data or not data.id then
        return
      end

      local utils = get_utils()
      -- Use the existing debounce mechanism from init.lua (via utils)
      utils.cancel_debounce()

      local state = get_state()
      state.debounce_timer = vim.uv.new_timer()
      state.debounce_timer:start(
        50, -- 50ms debounce threshold
        0,
        vim.schedule_wrap(function()
          utils.cancel_debounce()

          -- Early exit if we moved on, closed flog, or are running a command
          if not state.cwd or utils.has_active_job() then
            return
          end

          -- Don't reload if the same content is already open
          if
            preview_is_valid()
            and state.preview.type == data.type
            and state.preview.change_id == data.id
          then
            return
          end

          -- Build content asynchronously and open when done
          utils.build_preview_content_async(data.id, function(output)
            vim.schedule(function()
              -- Verify context is still valid after async wait
              if not state.cwd or utils.has_active_job() then
                return
              end
              if output then
                M.open(output, data.type, data.id, { filetype = 'jujutsu' })
              end
            end)
          end)
        end)
      )
    end,
  })
end

-- Call the setup immediately when the module is required
setup_preview_event_listener()

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

  -- Clear cached change_id to force update
  state.preview.change_id = nil
  vim.api.nvim_exec_autocmds('User', {
    pattern = 'JujutsuRevisionSelected',
    data = { id = id, type = preview_type },
  })
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
  -- Programmatic cursor moves don't fire CursorMoved; trigger it manually
  vim.api.nvim_exec_autocmds('CursorMoved', { buffer = state.buf })

  -- Update preview via custom event
  vim.api.nvim_exec_autocmds('User', {
    pattern = 'JujutsuRevisionSelected',
    data = { id = new_commit.id, type = 'show' },
  })
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
    '  New (n-prefix):',
    '  nn    new       - New commit after this one',
    '  nc    new @     - New commit after current',
    '  nd    new dev   - New commit after dev (if bookmark exists)',
    '',
    '  Commit (c-prefix):',
    '  cd    describe  - Edit description (<CR> save, q cancel)',
    '  cD    cdescribe - AI-generate description (async)',
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
    '  bd    bookmark  - Delete bookmark on commit',
    '  bf    bookmark  - Forget bookmark on commit',
    '  bm    bookmark  - Move bookmark to commit',
    '  bM    bookmark  - Move bookmark to commit with --allow-backwards',
    '  bt    bookmark  - Move trunk() bookmark (main/master) to commit',
    '',
    '  Git (g-prefix):',
    '  gf    fetch     - Git fetch from remote',
    '  gp    push      - Git push tracked bookmarks',
    '  gP    push      - Git push bookmark of current commit',
    '',
    '  Actions:',
    '  J     jump      - Move cursor to parent commit',
    '  K     jump      - Move cursor to child commit',
    '  e     edit      - Edit (checkout) commit',
    '  x     abandon   - Abandon commit (confirm)',
    '  y     yank      - Yank revision(s) (visual: earliest::latest)',
    '  yb    yank      - Yank bookmark name to clipboard',
    '  a     absorb    - Absorb working copy changes into revision',
    '  L     split     - Split revision',
    '  U     undo      - Undo last operation',
    '  R     redo      - Redo last undo',
    '',
    '  Navigation:',
    '  j/k       move  - Move by commit (2 lines)',
    '  <Tab>     next  - Navigate to next revision (in preview)',
    '  <S-Tab>   prev  - Navigate to previous revision (in preview)',
    '  <CR>      focus - Toggle log/preview focus',
    '  O/<CR>    diff  - Open file diff side-by-side (in preview)',
    '  v         view  - View file at revision (in preview)',
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

-- Export for use by file history popup and other callers
M.apply_highlights = apply_preview_highlights

return M
