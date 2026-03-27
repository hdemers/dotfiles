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
  EDITOR_CLOSE_DELAY_MS = 100,
  FLOAT_WIDTH = 100,
  HELP_WIDTH = 73,
  WATCHER_DEBOUNCE_MS = 200,
  REFRESH_DEDUP_MS = 300,
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
  watcher = nil, -- uv_fs_event_t handle for op_heads directory
  last_refresh_time = 0, -- Timestamp of last refresh (for dedup with watcher)
  serial_queue = {}, -- FIFO queue of pending async repo-modifying operations
  serial_running = false, -- whether a queued operation is active
}

--------------------------------------------------------------------------------
-- Utilities namespace (exposed for other modules)
--------------------------------------------------------------------------------

M.utils = {}

local jj_log_hl_ns = vim.api.nvim_create_namespace 'jujutsu_log'
local jj_history_hl_ns = vim.api.nvim_create_namespace 'jujutsu_history'

-- Forward declarations for functions defined later but used in refresh_log
local setup_keymaps
local setup_buffer_cleanup

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

-- Enqueue an async repo-modifying operation so they run serially.
-- `fn` receives a single `on_done` callback it must call when finished.
function M.utils.enqueue(fn)
  table.insert(M.state.serial_queue, fn)
  M.utils.drain_queue()
end

function M.utils.drain_queue()
  if M.state.serial_running or #M.state.serial_queue == 0 then return end
  M.state.serial_running = true
  local fn = table.remove(M.state.serial_queue, 1)
  fn(function()
    M.state.serial_running = false
    M.utils.drain_queue()
  end)
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

-- File watcher for external jj changes
local function start_watcher()
  if M.state.watcher then
    return
  end

  local op_heads_path = M.state.cwd .. '/.jj/repo/op_heads/heads'
  if vim.fn.isdirectory(op_heads_path) ~= 1 then
    return
  end

  M.state.watcher = vim.uv.new_fs_event()
  M.state.watcher:start(
    op_heads_path,
    {},
    vim.schedule_wrap(function(err, fname)
      -- Ignore errors, invalid state, and lock file churn
      if err or not state_is_valid() or fname == 'lock' then
        return
      end

      -- Debounce, then check timestamp INSIDE the callback (critical for race safety)
      debounce(function()
        -- Check timestamp AFTER debounce - catches actions during debounce window
        local now = vim.uv.now()
        if now - M.state.last_refresh_time < M.CONST.REFRESH_DEDUP_MS then
          return
        end

        if state_is_valid() then
          M.utils.refresh_log()
        end
      end, M.CONST.WATCHER_DEBOUNCE_MS)
    end)
  )
end

local function stop_watcher()
  if M.state.watcher then
    M.state.watcher:stop()
    M.state.watcher:close()
    M.state.watcher = nil
  end
end

-- Build unique-prefix maps for change IDs and commit IDs by querying jj.
-- Returns change_map {cid8 → unique_len} and commit_map {hex8 → unique_len}.
-- Both are used to split ID highlights into bright unique prefix + dim suffix.
local function build_unique_prefix_maps(cwd)
  local template = table.concat({
    'change_id.short(8)',
    '" "',
    'change_id.shortest()',
    '" "',
    'commit_id.short(8)',
    '" "',
    'commit_id.shortest()',
    '"\\n"',
  }, ' ++ ')
  local cmd = M.utils.build_jj_cmd(
    "log -r :: --no-graph -T '" .. template .. "'",
    cwd
  )
  local output = vim.fn.system(cmd)
  local change_map, commit_map = {}, {}
  for line in output:gmatch '[^\n]+' do
    local cid8, cprefix, xid8, xprefix =
      line:match '^([a-z0-9]+)%s+([a-z0-9]+)%s+([0-9a-f]+)%s+([0-9a-f]+)$'
    if cid8 and cprefix then
      change_map[cid8] = #cprefix
    end
    if xid8 and xprefix then
      commit_map[xid8] = #xprefix
    end
  end
  return change_map, commit_map
end

-- Apply syntax highlights to the plain-text log buffer.
-- Handles commit lines (marker + change_id + commit_id + bookmarks + date + description)
-- and graph-only connector lines.
-- change_map: optional {cid8 → unique_len} for change ID prefix split.
-- commit_map: optional {hex8 → unique_len} for commit ID prefix split.
local function apply_log_highlights(buf, lines, change_map, commit_map)
  vim.api.nvim_buf_clear_namespace(buf, jj_log_hl_ns, 0, -1)

  local function hl(lnum, group, col_start, col_end)
    vim.api.nvim_buf_add_highlight(buf, jj_log_hl_ns, group, lnum, col_start, col_end)
  end

  local prev_was_commit = false
  for i, line in ipairs(lines) do
    if line == '' then goto continue end
    local lnum = i - 1

    -- Elided line (~)
    if line:match '^[%s│]*~' then
      hl(lnum, 'JJElided', 0, -1)
      prev_was_commit = false
      goto continue
    end

    -- Detect commit line: requires marker + change_id pattern
    local full_cid = line:match '[│%s]*[◆◇○@◉×~][│%s]*([a-z][a-z0-9]+%/?%d*)%s+[a-z0-9]+'
    if not full_cid then
      if prev_was_commit then
        -- Description line: graph prefix as JJGraphLine, text with per-annotation colors
        local graph_prefix = line:match '^[│╭╰╯╮─├┤┬┴┼ ]+'
        local desc_col = graph_prefix and #graph_prefix or 0
        hl(lnum, 'JJGraphLine', 0, desc_col)
        if desc_col < #line then
          local desc_text = line:sub(desc_col + 1)
          local cur = desc_col -- 0-indexed current position
          -- Highlight (empty) annotation if present
          local saw_empty = false
          if desc_text:sub(1, 7) == '(empty)' then
            hl(lnum, 'String', cur, cur + 7)
            cur = cur + 7
            if desc_text:sub(8, 8) == ' ' then cur = cur + 1 end
            desc_text = line:sub(cur + 1)
            saw_empty = true
          end
          -- Remaining text
          if cur < #line then
            local rest_group = desc_text:find('(no description set)', 1, true)
                and (saw_empty and 'String' or 'JJAuthorEmail')
              or 'JJDescription'
            hl(lnum, rest_group, cur, -1)
          end
        end
      else
        hl(lnum, 'JJGraphLine', 0, -1)
      end
      prev_was_commit = false
      goto continue
    end

    -- Find byte position of change_id in the line
    local cid_start = line:find(full_cid, 1, true)
    if not cid_start then goto continue end
    local before = line:sub(1, cid_start - 1)

    -- Find marker character, its position in `before`, and its byte size
    local marker_pos, marker_size
    if before:find('@', 1, true) then
      marker_pos = before:find('@', 1, true)
      marker_size = 1
    elseif before:find('◆', 1, true) then
      marker_pos = before:find('◆', 1, true)
      marker_size = 3
    elseif before:find('×', 1, true) then
      marker_pos = before:find('×', 1, true)
      marker_size = 2
    else
      marker_pos = before:find('◇', 1, true)
        or before:find('○', 1, true)
        or before:find('◉', 1, true)
      marker_size = 3
    end

    -- Determine color group from marker character + bookmarks
    local marker_group
    if before:find('@', 1, true) then
      marker_group = 'JJWorkingCopy'
    elseif before:find('◆', 1, true) then
      marker_group = 'JJImmutable'
      if line:find(' master ', 1, true) or line:find(' main ', 1, true) then
        marker_group = 'JJTrunk'
      end
    elseif before:find('×', 1, true) then
      marker_group = 'JJAbandoned'
    else
      marker_group = 'JJMutable'
    end
    -- staging bookmark overrides any marker color
    if line:match ' staging%*? ' then
      marker_group = 'JJDev'
    end
    -- dev bookmark overrides any marker color
    if line:match ' dev%*? ' then
      marker_group = 'JJDev'
    end

    -- Highlight graph prefix then marker
    if marker_pos then
      hl(lnum, 'JJGraphLine', 0, marker_pos - 1)
      hl(lnum, marker_group, marker_pos - 1, marker_pos - 1 + marker_size)
    else
      hl(lnum, 'JJGraphLine', 0, cid_start - 1)
    end

    -- Check for (conflict) or (divergent) at the end of the line
    local conflict_s = line:find '%(conflict%)%s*$' -- 1-indexed; nil if absent
    local divergent_s = line:find '%(divergent%)%s*$' -- 1-indexed; nil if absent
    local annotation_s = conflict_s or divergent_s

    -- Change ID
    -- Change ID: bright unique prefix, dim non-unique suffix
    local base_cid, div_suffix = full_cid:match '^([a-z0-9]+)(/?%d*)$'
    local cid_unique_len = change_map and change_map[base_cid:sub(1, 8)]
    local unique_hl = divergent_s and 'Error' or 'JJChangeId'

    if cid_unique_len and cid_unique_len < #base_cid then
      hl(lnum, unique_hl, cid_start - 1, cid_start - 1 + cid_unique_len)
      hl(lnum, 'JJChangeIdDim', cid_start - 1 + cid_unique_len, cid_start - 1 + #base_cid)
    else
      hl(lnum, unique_hl, cid_start - 1, cid_start - 1 + #base_cid)
    end

    if div_suffix and #div_suffix > 0 then
      hl(lnum, 'Error', cid_start - 1 + #base_cid, cid_start - 1 + #full_cid)
    end

    -- Parse rest of line: commit_id, bookmarks, date, description
    local after_start = cid_start + #full_cid
    local rest = line:sub(after_start)

    -- Commit ID: last hex token on the line, optionally followed by (conflict) or (divergent).
    -- Computed early so description highlight can be clamped to stop before it.
    local xid = line:match '%s([0-9a-f]+)%s+%(conflict%)%s*$'
      or line:match '%s([0-9a-f]+)%s+%(divergent%)%s*$'
      or line:match '%s([0-9a-f]+)%s*$'
    local xid_abs_start -- 0-indexed; set below if xid is found
    if xid and #xid >= 4 then
      local line_before = annotation_s and line:sub(1, annotation_s - 1):match '^(.-)%s*$'
        or line:match '^(.-)%s*$'
      xid_abs_start = #line_before - #xid
    end

    local date_s, date_e = rest:find '%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d'
    if date_s then
      -- Email: pre-date region
      local pre_date = rest:sub(1, date_s - 1)
      for bm_s, word, bm_e in pre_date:gmatch '()(%S+)()' do
        if word:find('@', 1, true) then
          hl(lnum, 'JJAuthorEmail', after_start - 1 + bm_s - 1, after_start - 1 + bm_e - 1)
        end
      end
      -- Date+time
      hl(lnum, 'JJTimestamp', after_start - 1 + date_s - 1, after_start - 1 + date_e)
      -- Bookmarks: non-hex words between timestamp and commit ID
      local xid_in_rest = xid_abs_start and (xid_abs_start - after_start + 2)
      local post_date = rest:sub(date_e + 1, xid_in_rest and xid_in_rest - 1)
      local post_date_base = after_start - 1 + date_e
      for bm_s, word, bm_e in post_date:gmatch '()(%S+)()' do
        if not word:match '^[0-9a-f]+$' then
          local group = word:match '@$' and 'String' or 'JJBookmark'
          hl(lnum, group, post_date_base + bm_s - 1, post_date_base + bm_e - 1)
        end
      end
    elseif after_start <= #line then
      local desc_end = xid_abs_start or -1
      hl(lnum, 'JJDescription', after_start - 1, desc_end)
    end

    -- Commit ID: applied last so it wins over any overlapping description highlight
    if xid_abs_start then
      local xid_unique_len = commit_map and commit_map[xid:sub(1, 8)]
      if xid_unique_len and xid_unique_len < #xid then
        hl(lnum, 'JJCommitId', xid_abs_start, xid_abs_start + xid_unique_len)
        hl(lnum, 'JJCommitIdDim', xid_abs_start + xid_unique_len, xid_abs_start + #xid)
      else
        hl(lnum, 'JJCommitId', xid_abs_start, xid_abs_start + #xid)
      end
    end
    -- (conflict) or (divergent) annotation at end of line 1
    if conflict_s then
      hl(lnum, 'Error', conflict_s - 1, -1)
    end
    if divergent_s then
      hl(lnum, 'Error', divergent_s - 1, -1)
    end

    prev_was_commit = true
    ::continue::
  end
end

-- Apply syntax highlights to the file-history bottom panel.
-- padded_lines format: line 1 = file path header, line 2 = empty,
-- lines 3+ = '    change_id [bookmarks] [date] description' (builtin_log_oneline)
-- change_map: optional {cid8 → unique_len} from build_unique_prefix_maps.
local function apply_history_log_highlights(buf, lines, change_map)
  vim.api.nvim_buf_clear_namespace(buf, jj_history_hl_ns, 0, -1)

  local function hl(lnum, group, col_start, col_end)
    vim.api.nvim_buf_add_highlight(buf, jj_history_hl_ns, group, lnum, col_start, col_end)
  end

  for i, line in ipairs(lines) do
    if line == '' then goto continue end
    local lnum = i - 1

    if i == 1 then
      hl(lnum, 'JJHeaderKey', 0, -1)
      goto continue
    end

    if i < 3 then goto continue end

    -- Commit line: '    change_id ...'
    local cid = line:match '^%s*([a-z][a-z0-9]+%/?%d*)'
    if not cid then goto continue end

    local divergent_s = line:find '%(divergent%)%s*$'
    local cid_start = line:find(cid, 1, true)
    local base_cid, div_suffix = cid:match '^([a-z0-9]+)(/?%d*)$'
    local unique_len = change_map and change_map[base_cid:sub(1, 8)]
    local unique_hl = divergent_s and 'Error' or 'JJChangeId'

    if unique_len and unique_len < #base_cid then
      hl(lnum, unique_hl, cid_start - 1, cid_start - 1 + unique_len)
      hl(lnum, 'JJChangeIdDim', cid_start - 1 + unique_len, cid_start - 1 + #base_cid)
    else
      hl(lnum, unique_hl, cid_start - 1, cid_start - 1 + #base_cid)
    end

    if div_suffix and #div_suffix > 0 then
      hl(lnum, 'Error', cid_start - 1 + #base_cid, cid_start - 1 + #cid)
    end

    local after_start = cid_start + #cid
    local rest = line:sub(after_start)
    local date_s, date_e = rest:find '%d%d%d%d%-%d%d%-%d%d'
    if date_s then
      hl(lnum, 'JJTimestamp', after_start - 1 + date_s - 1, after_start - 1 + date_e)
      local desc_start = after_start - 1 + date_e
      if desc_start < #line then
        hl(lnum, 'JJDescription', desc_start, -1)
      end
    elseif after_start <= #line then
      hl(lnum, 'JJDescription', after_start - 1, -1)
    end

    if divergent_s then
      hl(lnum, 'Error', divergent_s - 1, -1)
    end

    ::continue::
  end
end

function M.utils.get_change_id_from_line(line)
  -- Plain text only: log buffer no longer contains ANSI codes
  -- Require a commit marker (◆◇○@◉×~) to distinguish commit lines from graph/description lines
  local change_id = line:match '[│%s]*[◆◇○@◉×~][│%s]*([a-z][a-z0-9]+%/?%d*)%s+[a-z0-9]+'
  if change_id then
    local base_cid, suffix = change_id:match '^([a-z0-9]+)(/?%d*)$'
    if base_cid and #base_cid >= M.CONST.CHANGE_ID_LENGTH then
      return base_cid:sub(1, M.CONST.CHANGE_ID_LENGTH) .. suffix
    end
  end
  return nil
end

function M.utils.get_change_id_under_cursor()
  return M.utils.get_change_id_from_line(vim.api.nvim_get_current_line())
end

--- Get the IDs of revisions related to a specific commit by offset (+ for children, - for parents)
--- @param id string The change ID or commit ID
--- @param offset string The offset character ('+' or '-')
--- @return table|nil List of string IDs, or nil if error/none
function M.utils.get_related_ids(id, offset)
  -- The template ensures each ID is on its own line
  local cmd = string.format('log -r "%s%s" --no-graph -T \'change_id ++ "\\n"\'', id, offset)
  local output, success = M.utils.run_jj_cmd(cmd, nil, { notify = false })

  if not success or not output or output == '' then
    return nil
  end

  local ids = vim.split(vim.trim(output), '\n', { trimempty = true })
  return #ids > 0 and ids or nil
end

--- Get the first parent ID of a revision
--- @param id string The change ID
--- @return string|nil The parent change ID
function M.utils.get_parent_id(id)
  local ids = M.utils.get_related_ids(id, '-')
  return ids and ids[1] or nil
end

--- Get the first child ID (descendant) of a revision
--- @param id string The change ID
--- @return string|nil The child change ID
function M.utils.get_child_id(id)
  local ids = M.utils.get_related_ids(id, '+')
  return ids and ids[1] or nil
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
  -- Check summary format: "M path/to/file" (jj diff --summary)
  local current = lines[cursor_line]
  if current then
    local summary_match = current:match '^[MADR] (.+)$'
    if summary_match then
      return summary_match
    end
  end
  -- Fall back to git diff format: "diff --git a/path b/path"
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
  local parts = { 'cd', vim.fn.shellescape(cwd), '&&', 'COLUMNS=9999', 'jj' }
  if type(args) == 'string' then
    table.insert(parts, args)
  else
    for _, arg in ipairs(args) do
      table.insert(parts, arg)
    end
  end
  return table.concat(parts, ' ')
end

-- Returns nil if the revision doesn't exist or jj errors out.
function M.utils.build_preview_content(id)
  if id:find '::' then
    local summary = vim.fn.system(M.utils.build_jj_cmd('diff --summary -r ' .. id))
    if vim.v.shell_error ~= 0 then
      return nil
    end
    return 'Range: ' .. id .. '\n\n' .. summary
  else
    local header = vim.fn.system(
      M.utils.build_jj_cmd('log --no-graph -r ' .. id .. ' -T builtin_log_detailed')
    )
    if vim.v.shell_error ~= 0 then
      return nil
    end
    local summary = vim.fn.system(M.utils.build_jj_cmd('diff --summary -r ' .. id))
    local conflicts = vim.fn.system(M.utils.build_jj_cmd('resolve --list -r ' .. id))
    local result = header .. summary
    if vim.v.shell_error == 0 and conflicts:match '%S' then
      result = result .. '\nConflicts:\n' .. conflicts
    end
    return result
  end
end

function M.utils.build_preview_content_async(id, callback)
  local function build_cmd(args)
    return M.utils.build_jj_cmd(args)
  end

  local is_range = id:find '::' ~= nil

  if is_range then
    vim.fn.jobstart(build_cmd('diff --summary -r ' .. id), {
      stdout_buffered = true,
      on_exit = function(_, exit_code, _)
        if exit_code ~= 0 then
          callback(nil)
          return
        end
      end,
      on_stdout = function(_, data, _)
        if #data > 0 then
          local summary = table.concat(data, '\n')
          callback('Range: ' .. id .. '\n\n' .. summary)
        else
          callback(nil)
        end
      end,
    })
  else
    -- For single commits, we need to run multiple commands. We'll chain them or use a small helper script.
    -- For simplicity and speed, a combined shell command works well.
    local cmd = string.format(
      "jj log --no-graph -r %s -T builtin_log_detailed && jj diff --summary -r %s && echo 'Conflicts:' && jj resolve --list -r %s",
      vim.fn.shellescape(id),
      vim.fn.shellescape(id),
      vim.fn.shellescape(id)
    )

    -- Note: build_jj_cmd returns a table or string depending on OS. We'll assume a shell execution context.
    local full_cmd = 'cd ' .. vim.fn.shellescape(M.state.cwd) .. ' && ' .. cmd

    vim.fn.jobstart(full_cmd, {
      stdout_buffered = true,
      on_stdout = function(_, data, _)
        if #data > 0 then
          local result = table.concat(data, '\n')
          -- Clean up empty 'Conflicts:' if none exist
          result = result:gsub('\nConflicts:\n$', '')
          callback(result)
        else
          callback(nil)
        end
      end,
      on_exit = function(_, exit_code, _)
        if exit_code ~= 0 then
          -- If the command failed entirely, we might want to return nil
          -- but jobstart async stdout fires before exit.
        end
      end,
    })
  end
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
    end, M.CONST.EDITOR_CLOSE_DELAY_MS)
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
        -- Restore cursor before refresh so refresh_log preserves it
        if session.saved_cursor and is_win_valid(M.state.win) then
          pcall(vim.api.nvim_win_set_cursor, M.state.win, session.saved_cursor)
        end
        M.utils.refresh_log()
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

-- Refresh the preview for the given id (called after log refresh).
-- The id is extracted from raw jj output, not from the terminal buffer,
-- to avoid terminal rendering race conditions.
local function refresh_preview_after_log(id)
  if not M.state.cwd or not id then
    return
  end
  local preview = require 'legacy_jujutsu.preview'
  if not is_win_valid(M.state.preview.win) then
    return
  end

  vim.schedule(function()
    if
      not M.state.cwd
      or not is_win_valid(M.state.preview.win)
      or M.utils.has_active_job()
    then
      return
    end
    local preview_type = M.state.preview.type or 'show'
    M.state.preview.change_id = nil -- force update
    vim.api.nvim_exec_autocmds('User', {
      pattern = 'JujutsuRevisionSelected',
      data = { id = id, type = preview_type },
    })
  end)
end

function M.utils.refresh_log()
  -- Early exit if plugin was closed (cwd is nil when fully closed)
  if not M.state.cwd or not state_is_valid() then
    return
  end

  -- Track refresh time for watcher deduplication
  M.state.last_refresh_time = vim.uv.now()

  -- Save cursor before modifications
  local cursor = vim.api.nvim_win_get_cursor(M.state.win)

  local output = vim.fn.system(M.utils.build_jj_cmd 'log -r ::')
  local lines = vim.split(output, '\n')
  local line_count = #lines

  -- Update buffer in-place (synchronous plain-text rendering, no terminal swap)
  local change_map, commit_map = build_unique_prefix_maps(M.state.cwd)
  vim.bo[M.state.buf].modifiable = true
  vim.api.nvim_buf_set_lines(M.state.buf, 0, -1, false, lines)
  apply_log_highlights(M.state.buf, lines, change_map, commit_map)
  vim.bo[M.state.buf].modifiable = false

  -- Restore cursor, clamped to valid range
  local row = math.min(cursor[1], math.max(1, line_count))
  pcall(vim.api.nvim_win_set_cursor, M.state.win, { row, cursor[2] })

  -- Refresh preview if open
  if is_win_valid(M.state.preview.win) then
    local id = M.utils.get_change_id_from_line(lines[row])
    if not id and row > 1 then
      id = M.utils.get_change_id_from_line(lines[row - 1])
    end
    refresh_preview_after_log(id)
  end
end

--------------------------------------------------------------------------------
-- Close flog
--------------------------------------------------------------------------------

local function close_flog()
  local preview = require 'legacy_jujutsu.preview'

  M.utils.cancel_debounce()
  stop_watcher()
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

setup_keymaps = function(buf)
  local actions = require 'legacy_jujutsu.actions'
  local preview = require 'legacy_jujutsu.preview'

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

  -- Insert change operations (i-prefix)
  vim.keymap.set('n', 'in', actions.new, { buffer = buf, nowait = true })
  vim.keymap.set('n', 'ic', actions.new_current, { buffer = buf, nowait = true })
  vim.keymap.set('n', 'id', actions.new_dev, { buffer = buf, nowait = true })

  -- Commit operations (c-prefix)
  vim.keymap.set({ 'n', 'x' }, 'cd', actions.describe, { buffer = buf, nowait = true })
  vim.keymap.set({ 'n', 'x' }, 'cD', actions.cdescribe, { buffer = buf, nowait = true })
  vim.keymap.set({ 'n', 'x' }, 'cs', actions.squash, { buffer = buf, nowait = true })
  vim.keymap.set({ 'n', 'x' }, 'cS', actions.squash_into, { buffer = buf, nowait = true })

  -- Rebase operations (r-prefix)
  vim.keymap.set({ 'n', 'x' }, 'rr', actions.rebase, { buffer = buf, nowait = true })
  vim.keymap.set(
    { 'n', 'x' },
    'ri',
    actions.rebase_interactive,
    { buffer = buf, nowait = true }
  )
  vim.keymap.set({ 'n', 'x' }, 'rd', actions.duplicate, { buffer = buf, nowait = true })
  vim.keymap.set('n', 'rw', actions.switch_revisions, { buffer = buf, nowait = true })
  vim.keymap.set('x', 'rp', actions.parallelize, { buffer = buf, nowait = true })

  -- Bookmark operations (b-prefix)
  vim.keymap.set('n', 'bb', actions.bookmark, { buffer = buf, nowait = true })
  vim.keymap.set('n', 'bd', actions.delete_bookmark, { buffer = buf, nowait = true })
  vim.keymap.set('n', 'bf', actions.forget_bookmark, { buffer = buf, nowait = true })
  vim.keymap.set('n', 'bm', actions.move_bookmark(), { buffer = buf, nowait = true })
  vim.keymap.set(
    'n',
    'bM',
    actions.move_bookmark { allow_backwards = true },
    { buffer = buf, nowait = true }
  )
  vim.keymap.set('n', 'bt', actions.move_trunk_bookmark, { buffer = buf, nowait = true })

  -- Git operations (g-prefix)
  vim.keymap.set('n', 'gf', actions.fetch, { buffer = buf, nowait = true })
  vim.keymap.set('n', 'gp', actions.push, { buffer = buf, nowait = true })
  vim.keymap.set('n', 'gP', actions.push_bookmark, { buffer = buf, nowait = true })

  -- Single-key actions
  vim.keymap.set('n', 'e', actions.edit, { buffer = buf, nowait = true })
  vim.keymap.set('n', 'J', actions.move_to_parent, { buffer = buf, nowait = true })
  vim.keymap.set('n', 'K', actions.move_to_child, { buffer = buf, nowait = true })
  vim.keymap.set({ 'n', 'x' }, 'x', actions.abandon, { buffer = buf, nowait = true })
  vim.keymap.set({ 'n', 'x' }, 'y', actions.yank, { buffer = buf, nowait = true })
  vim.keymap.set('n', 'yb', actions.yank_bookmark, { buffer = buf, nowait = true })
  vim.keymap.set({ 'n', 'x' }, 'a', actions.absorb, { buffer = buf, nowait = true })
  vim.keymap.set('n', 'U', actions.undo, { buffer = buf, nowait = true })
  vim.keymap.set('n', 'R', actions.redo, { buffer = buf, nowait = true })
  vim.keymap.set('n', 'L', actions.split, { buffer = buf, nowait = true })

  -- UI
  vim.keymap.set(
    { 'n', 'x' },
    '<CR>',
    preview.toggle_focus,
    { buffer = buf, nowait = true }
  )
  vim.keymap.set('n', 'g?', preview.show_help, { buffer = buf, nowait = true })
  vim.keymap.set('n', 'gq', close_flog, { buffer = buf, nowait = true })
end

--------------------------------------------------------------------------------
-- Buffer lifecycle helpers
--------------------------------------------------------------------------------

-- Sets up close/cleanup infrastructure on a log buffer.
-- Called once on initial creation and again each time refresh_log
-- replaces the buffer.
setup_buffer_cleanup = function(buf)
  -- Intercept :tabclose to use proper cleanup (prevents crashes)
  vim.api.nvim_buf_call(buf, function()
    vim.cmd.cnoreabbrev '<buffer> tabclose JJClose'
  end)
  vim.api.nvim_buf_create_user_command(buf, 'JJClose', function()
    close_flog()
  end, { bang = true })
  vim.keymap.set('n', '<leader>w', close_flog, { buffer = buf, nowait = true })

  -- Cleanup when buffer is wiped (e.g., by tabclose)
  vim.api.nvim_create_autocmd('BufWipeout', {
    buffer = buf,
    once = true,
    callback = function()
      M.utils.cancel_debounce()
      stop_watcher()
      if M.state.active_job then
        pcall(vim.fn.jobstop, M.state.active_job)
      end
      M.state.preview = { buf = nil, win = nil, type = nil, change_id = nil }
      M.state.win = nil
      M.state.buf = nil
      M.state.active_job = nil
      M.state.cwd = nil
    end,
  })
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

function M.jujutsu_flog()
  local preview = require 'legacy_jujutsu.preview'
  local actions = require 'legacy_jujutsu.actions'

  if state_is_valid() then
    vim.api.nvim_set_current_win(M.state.win)
    return
  end

  -- Clean up any existing JJ-log buffer BEFORE setting state
  -- (deleting triggers BufWipeout which clears state)
  local existing = vim.fn.bufnr 'JJ-log'
  if existing ~= -1 then
    pcall(vim.api.nvim_clear_autocmds, { buffer = existing, event = 'BufWipeout' })
    vim.api.nvim_buf_delete(existing, { force = true })
  end
  require('legacy_jujutsu.preview').close()

  M.state.cwd = vim.fn.getcwd()

  local output = vim.fn.system(M.utils.build_jj_cmd 'log -r ::')

  vim.cmd 'tabnew'
  local buf = vim.api.nvim_get_current_buf()
  M.state.buf = buf
  M.state.win = vim.api.nvim_get_current_win()

  vim.api.nvim_buf_set_name(buf, 'JJ-log')
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].buflisted = false

  -- Set window display options once at buffer creation
  vim.api.nvim_win_call(M.state.win, function()
    vim.wo.number = false
    vim.wo.relativenumber = false
    vim.wo.statuscolumn = ''
    vim.wo.signcolumn = 'no'
    vim.wo.cursorline = true
    vim.wo.wrap = false
  end)

  local cursorline_group =
    vim.api.nvim_create_augroup('JJLogCursorline_' .. buf, { clear = true })
  vim.api.nvim_create_autocmd({ 'WinEnter', 'BufEnter' }, {
    group = cursorline_group,
    buffer = buf,
    callback = function()
      vim.wo.cursorline = true
    end,
  })
  vim.api.nvim_create_autocmd({ 'WinLeave', 'BufLeave' }, {
    group = cursorline_group,
    buffer = buf,
    callback = function()
      vim.wo.cursorline = false
    end,
  })

  local lines = vim.split(output, '\n')
  local change_map, commit_map = build_unique_prefix_maps(M.state.cwd)
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  apply_log_highlights(buf, lines, change_map, commit_map)
  vim.bo[buf].modifiable = false

  setup_keymaps(buf)
  preview.setup_dual_cursorline(buf, M.state.win)
  setup_buffer_cleanup(buf)

  -- Start file watcher for external jj changes
  start_watcher()

  -- Rendering is synchronous: use vim.schedule instead of a fixed delay
  vim.schedule(function()
    if M.state.cwd and is_win_valid(M.state.win) and not M.utils.has_active_job() then
      vim.api.nvim_win_set_cursor(M.state.win, { 1, 0 })
      actions.show()
    end
  end)
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

function M.jujutsu_file_history(file_path, target_cid)
  -- Handle being called as a Neovim user command where the first arg is an opts table
  if type(file_path) == 'table' then
    file_path = nil
  end

  file_path = file_path or vim.fn.expand '%'
  if file_path == '' then
    vim.notify('No file to show history for', vim.log.levels.WARN)
    return
  end
  local ft = vim.filetype.match { filename = file_path }

  M.state.cwd = vim.fn.getcwd()

  local cmd = M.utils.build_jj_cmd(
    'log -r \'files("' .. file_path .. '")\' --no-graph -T builtin_log_oneline'
  )
  local output = vim.fn.system(cmd)

  local left_name = 'JJ-left-' .. vim.fn.fnamemodify(file_path, ':t')
  local right_name = 'JJ-right-' .. vim.fn.fnamemodify(file_path, ':t')
  local bot_name = 'JJ-file-history-' .. vim.fn.fnamemodify(file_path, ':t')

  for _, name in ipairs { left_name, right_name, bot_name } do
    local existing = vim.fn.bufnr(name)
    if existing ~= -1 then
      vim.api.nvim_buf_delete(existing, { force = true })
    end
  end

  -- Left window (old content)
  vim.cmd 'tabnew'
  local left_win = vim.api.nvim_get_current_win()
  local left_buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_name(left_buf, left_name)
  vim.bo[left_buf].buftype = 'nofile'
  vim.bo[left_buf].bufhidden = 'wipe'
  vim.bo[left_buf].buflisted = false
  if ft then
    vim.bo[left_buf].filetype = ft
  end
  vim.cmd 'diffthis'

  -- Right window (new content)
  vim.cmd 'rightbelow vsplit'
  local right_win = vim.api.nvim_get_current_win()
  local right_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(right_win, right_buf)
  vim.api.nvim_buf_set_name(right_buf, right_name)
  vim.bo[right_buf].buftype = 'nofile'
  vim.bo[right_buf].bufhidden = 'wipe'
  vim.bo[right_buf].buflisted = false
  if ft then
    vim.bo[right_buf].filetype = ft
  end
  vim.cmd 'diffthis'

  -- Bottom window (history log)
  local total_height = vim.api.nvim_get_option 'lines'
  local bot_height = math.floor(total_height / 5)
  vim.cmd('botright ' .. bot_height .. 'new')

  local bot_win = vim.api.nvim_get_current_win()
  local bot_buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_name(bot_buf, bot_name)
  vim.bo[bot_buf].buftype = 'nofile'
  vim.bo[bot_buf].bufhidden = 'wipe'
  vim.bo[bot_buf].buflisted = false

  local function close_tabs()
    vim.cmd 'tabclose'
  end
  vim.keymap.set('n', 'q', close_tabs, { buffer = bot_buf, silent = true })
  vim.keymap.set('n', 'q', close_tabs, { buffer = left_buf, silent = true })
  vim.keymap.set('n', 'q', close_tabs, { buffer = right_buf, silent = true })

  local function show_revision_info()
    if not is_win_valid(bot_win) then
      return
    end
    local line = vim.api.nvim_buf_get_lines(
      bot_buf,
      vim.api.nvim_win_get_cursor(bot_win)[1] - 1,
      vim.api.nvim_win_get_cursor(bot_win)[1],
      false
    )[1]
    if not line then
      return
    end

    local change_id = line:match '^%s*([a-z0-9]+)'
    if not change_id then
      return
    end

    local show_cmd = M.utils.build_jj_cmd('show --types -r ' .. change_id)
    local show_output = vim.fn.system(show_cmd)
    local show_lines = vim.split(show_output, '\n')

    -- Calculate popup dimensions
    local width = math.min(90, vim.o.columns - 4)
    local height = math.min(30, vim.o.lines - 4)
    local col = math.floor((vim.o.columns - width) / 2)
    local row = math.floor((vim.o.lines - height) / 2)

    local popup_buf = vim.api.nvim_create_buf(false, true)
    local popup_win = vim.api.nvim_open_win(popup_buf, true, {
      relative = 'editor',
      width = width,
      height = height,
      col = col,
      row = row,
      style = 'minimal',
      border = 'rounded',
      title = ' Revision: ' .. change_id .. ' ',
      title_pos = 'center',
    })

    vim.bo[popup_buf].buftype = 'nofile'
    vim.bo[popup_buf].bufhidden = 'wipe'

    vim.bo[popup_buf].modifiable = true
    vim.api.nvim_buf_set_lines(popup_buf, 0, -1, false, show_lines)
    require('legacy_jujutsu.preview').apply_highlights(popup_buf, show_lines)
    vim.bo[popup_buf].modifiable = false

    vim.keymap.set(
      'n',
      'q',
      '<C-w>q',
      { buffer = popup_buf, silent = true, nowait = true }
    )
    vim.keymap.set(
      'n',
      '<Esc>',
      '<C-w>q',
      { buffer = popup_buf, silent = true, nowait = true }
    )
    vim.keymap.set(
      'n',
      '<CR>',
      '<C-w>q',
      { buffer = popup_buf, silent = true, nowait = true }
    )
  end

  local function open_in_log()
    if not is_win_valid(bot_win) then return end
    local cursor_row = vim.api.nvim_win_get_cursor(bot_win)[1]
    local line = vim.api.nvim_buf_get_lines(bot_buf, cursor_row - 1, cursor_row, false)[1]
    if not line then return end
    local change_id = line:match '^%s*([a-z0-9]+)'
    if not change_id then return end

    vim.cmd 'tabclose'

    vim.schedule(function()
      local log_buf = vim.fn.bufnr 'JJ-log'
      if log_buf == -1 then return end
      local log_wins = vim.fn.win_findbuf(log_buf)
      if #log_wins == 0 then return end
      local log_win = log_wins[1]

      vim.api.nvim_set_current_win(log_win)

      local log_buf = vim.fn.bufnr 'JJ-log'
      local lines = log_buf ~= -1 and vim.api.nvim_buf_get_lines(log_buf, 0, -1, false) or {}

      local preview = require 'legacy_jujutsu.preview'
      for i, l in ipairs(lines) do
        local id = M.utils.get_change_id_from_line(l)
        if id and (vim.startswith(change_id, id) or vim.startswith(id, change_id)) then
          pcall(vim.api.nvim_win_set_cursor, log_win, { i, 4 })
          vim.api.nvim_exec_autocmds('CursorMoved', { buffer = log_buf })
          vim.api.nvim_exec_autocmds('User', {
            pattern = 'JujutsuRevisionSelected',
            data = { id = id, type = 'show' },
          })
          break
        end
      end
    end)
  end

  vim.keymap.set(
    'n',
    '<CR>',
    show_revision_info,
    { buffer = bot_buf, silent = true, desc = 'Show revision details' }
  )

  vim.keymap.set(
    'n',
    'L',
    open_in_log,
    { buffer = bot_buf, silent = true, desc = 'Open revision in log view' }
  )

  local function update_diffs()
    if not is_win_valid(bot_win) then
      return
    end
    local line = vim.api.nvim_buf_get_lines(
      bot_buf,
      vim.api.nvim_win_get_cursor(bot_win)[1] - 1,
      vim.api.nvim_win_get_cursor(bot_win)[1],
      false
    )[1]
    if not line then
      return
    end

    local change_id = line:match '^%s*([a-z0-9]+)'

    if not change_id then
      return
    end

    local old_cmd = M.utils.build_jj_cmd(
      'file show -r ' .. change_id .. '- ' .. vim.fn.shellescape(file_path)
    )
    local old_output = vim.fn.system(old_cmd)
    local old_lines = vim.v.shell_error == 0 and vim.split(old_output, '\n')
      or { 'File not found in parent' }

    local new_cmd = M.utils.build_jj_cmd(
      'file show -r ' .. change_id .. ' ' .. vim.fn.shellescape(file_path)
    )
    local new_output = vim.fn.system(new_cmd)
    local new_lines = vim.v.shell_error == 0 and vim.split(new_output, '\n')
      or { 'File not found in revision' }

    if is_buf_valid(left_buf) then
      vim.bo[left_buf].modifiable = true
      vim.api.nvim_buf_set_lines(left_buf, 0, -1, false, old_lines)
      vim.bo[left_buf].modifiable = false
    end

    if is_buf_valid(right_buf) then
      vim.bo[right_buf].modifiable = true
      vim.api.nvim_buf_set_lines(right_buf, 0, -1, false, new_lines)
      vim.bo[right_buf].modifiable = false
    end
  end

  local lines = vim.split(output, '\n')
  local padded_lines = {
    '    ' .. file_path,
    '',
  }
  for _, line in ipairs(lines) do
    table.insert(padded_lines, '    ' .. line)
  end

  local function next_rev()
    if not is_win_valid(bot_win) then
      return
    end
    local cursor = vim.api.nvim_win_get_cursor(bot_win)
    local max_line = #padded_lines
    if cursor[1] < max_line then
      vim.api.nvim_win_set_cursor(bot_win, { cursor[1] + 1, 4 })
      update_diffs()
    end
  end

  local function prev_rev()
    if not is_win_valid(bot_win) then
      return
    end
    local cursor = vim.api.nvim_win_get_cursor(bot_win)
    if cursor[1] > 3 then
      vim.api.nvim_win_set_cursor(bot_win, { cursor[1] - 1, 4 })
      update_diffs()
    end
  end

  for _, buf in ipairs { left_buf, right_buf, bot_buf } do
    vim.keymap.set(
      'n',
      '<Tab>',
      next_rev,
      { buffer = buf, silent = true, desc = 'Older revision' }
    )
    vim.keymap.set(
      'n',
      '<S-Tab>',
      prev_rev,
      { buffer = buf, silent = true, desc = 'Newer revision' }
    )
  end

  local change_map, commit_map = build_unique_prefix_maps(M.state.cwd)
  vim.bo[bot_buf].modifiable = true
  vim.api.nvim_buf_set_lines(bot_buf, 0, -1, false, padded_lines)
  apply_history_log_highlights(bot_buf, padded_lines, change_map)
  vim.bo[bot_buf].modifiable = false

  vim.api.nvim_win_call(bot_win, function()
    vim.wo.number = false
    vim.wo.relativenumber = false
    vim.wo.statuscolumn = ''
    vim.wo.signcolumn = 'no'
    vim.wo.cursorline = true
  end)

  local augroup =
    vim.api.nvim_create_augroup('JJFileHistory_' .. bot_buf, { clear = true })

  vim.api.nvim_create_autocmd('CursorMoved', {
    group = augroup,
    buffer = bot_buf,
    callback = function()
      local cursor = vim.api.nvim_win_get_cursor(0)
      local row = cursor[1]
      local max_line = #padded_lines
      if row < 3 then
        row = 3
      elseif row > max_line then
        row = max_line
      end
      -- Always constrain column to 4 (5th column)
      pcall(vim.api.nvim_win_set_cursor, 0, { row, 4 })

      update_diffs()
    end,
  })

  vim.api.nvim_set_current_win(bot_win)

  local target_row = 3 -- default to first valid row
  if target_cid then
    local oldest, newest = target_cid:match('^([^:]+)::(.+)$')
    local targets = oldest and { newest, oldest } or { target_cid }

    local found = false
    for _, target in ipairs(targets) do
      if found then break end
      local clean_target = vim.trim(target)

      for i = 3, #padded_lines do
        local line = padded_lines[i]
        local id = line:match('^%s*([a-z0-9]+)')

        if id then
          if string.find(clean_target, id, 1, true) or string.find(id, clean_target, 1, true) then
            target_row = i
            found = true
            break
          end
        end
      end
    end
  end

  -- Rendering is synchronous: set cursor directly
  pcall(vim.api.nvim_win_set_cursor, bot_win, { target_row, 4 })
  update_diffs()
end
local function smart_history()
  if is_jujutsu_repo() then
    M.jujutsu_file_history()
  else
    vim.cmd 'DiffviewFileHistory %'
  end
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
  vim.keymap.set('n', '<leader>ji', M.jujutsu_new, { desc = 'Insert new Jujutsu change' })
  vim.keymap.set('n', '<leader>gl', smart_log, { desc = 'Git/Jujutsu log (smart)' })
  vim.keymap.set(
    'n',
    '<leader>gh',
    smart_history,
    { desc = 'Diffview/Jujutsu file history (smart)' }
  )

  -- User commands
  vim.api.nvim_create_user_command('JujutsuLog', M.jujutsu_flog, {})
  vim.api.nvim_create_user_command('JujutsuNew', M.jujutsu_new, {})
  vim.api.nvim_create_user_command('JujutsuFileHistory', M.jujutsu_file_history, {})
end

return M
