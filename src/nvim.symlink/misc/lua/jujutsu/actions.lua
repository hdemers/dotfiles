-- vim: ts=2 sts=2 sw=2 et
-- jujutsu/actions.lua - Action definitions for jujutsu flog

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

local function get_preview()
  return require 'jujutsu.preview'
end

--------------------------------------------------------------------------------
-- Validation helpers
--------------------------------------------------------------------------------

local function is_win_valid(win)
  return win and vim.api.nvim_win_is_valid(win)
end

local function is_buf_valid(buf)
  return buf and vim.api.nvim_buf_is_valid(buf)
end

local function is_visual()
  local mode = vim.fn.mode()
  return mode == 'v' or mode == 'V' or mode == '\22'
end

local function exit_visual_mode()
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, false, true), 'nx', false)
end

--------------------------------------------------------------------------------
-- Revset extraction
--------------------------------------------------------------------------------

--- Get revset from current context (cursor or visual selection)
--- Does NOT exit visual mode - use for preview/read-only operations
---@return string|nil revset
local function get_revset()
  local state = get_state()
  local utils = get_utils()

  if not is_visual() then
    return utils.get_change_id_under_cursor()
  end

  local start_line = vim.fn.line 'v'
  local end_line = vim.fn.line '.'
  if start_line > end_line then
    start_line, end_line = end_line, start_line
  end

  local lines = vim.api.nvim_buf_get_lines(state.buf, start_line - 1, end_line, false)
  local change_ids = {}
  local seen = {}
  for _, line in ipairs(lines) do
    local id = utils.get_change_id_from_line(line)
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

--------------------------------------------------------------------------------
-- Simplified action wrapper
--------------------------------------------------------------------------------

--- Execute an action with a revset (single revision or range)
--- In visual mode: exits visual mode before running action
---@param action_fn function(revset: string, chosen?: string)
---@param opts? { refresh?: boolean }
---@return function
local function with_revset(action_fn, opts)
  opts = opts or {}
  return function()
    local utils = get_utils()
    local was_visual = is_visual()
    local revset = get_revset()

    if not revset then
      local msg = was_visual and 'No change IDs found in selection' or 'No change ID found on this line'
      vim.notify(msg, vim.log.levels.WARN)
      return
    end

    local function run_action(chosen)
      action_fn(revset, chosen)
      if opts.refresh ~= false then
        utils.refresh_log()
      end
    end

    if was_visual then
      exit_visual_mode()
      vim.schedule(run_action)
    else
      run_action()
    end
  end
end

--------------------------------------------------------------------------------
-- Action definitions
--------------------------------------------------------------------------------

M.edit = with_revset(function(id)
  local utils = get_utils()
  utils.run_jj_cmd('edit', id)
end)

M.new = with_revset(function(id)
  local utils = get_utils()
  utils.run_jj_cmd('new', id)
end)

function M.new_current()
  local utils = get_utils()
  utils.run_jj_cmd('new', '')
  utils.refresh_log()
end

M.describe = with_revset(function(id)
  local utils = get_utils()
  utils.run_jj_with_editor('describe ' .. id, ' Describe ' .. id .. ' ')
end, { refresh = false }) -- refresh handled by editor callback

M.diff = with_revset(function(id)
  local utils = get_utils()
  local preview = get_preview()
  local output = vim.fn.system(utils.build_jj_cmd('diff -r ' .. id .. ' --git'))
  preview.open(output, 'diff', id, { filetype = 'jujutsu', no_colorize = true })
end, { refresh = false })

M.show = with_revset(function(id)
  local state = get_state()
  local utils = get_utils()
  local preview = get_preview()

  local cursor = vim.api.nvim_win_get_cursor(state.win)
  local win = state.win

  -- Use diff for ranges (oldest::newest), show for single revisions
  local is_range = id:find '::'
  local cmd = is_range and ('diff -r ' .. id .. ' --git') or ('show -r ' .. id .. ' --git')
  local preview_type = is_range and 'diff' or 'show'

  local output = vim.fn.system(utils.build_jj_cmd(cmd))
  preview.open(output, preview_type, id, { filetype = 'jujutsu', no_colorize = true })

  vim.defer_fn(function()
    if is_win_valid(win) then
      vim.api.nvim_win_set_cursor(win, cursor)
    end
  end, 10)
end, { refresh = false })

M.squash = with_revset(function(revset)
  local utils = get_utils()
  local cmd
  if revset:find '::' then
    local oldest = revset:match '^([^:]+)'
    cmd = string.format('squash -f %s -t %s', revset, oldest)
  else
    cmd = 'squash -r ' .. revset
  end
  utils.run_jj_with_editor(cmd, ' Squash ' .. revset .. ' ')
end, { refresh = false })

M.squash_into = with_revset(function(revset)
  local utils = get_utils()
  local destinations = utils.get_revisions { revset = 'trunk()..' }
  if not destinations or #destinations == 0 then
    vim.notify('No revisions found from: trunk()..', vim.log.levels.WARN)
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
      local cmd = string.format('squash -f %s -t %s', revset, chosen_id)
      utils.run_jj_with_editor(cmd, ' Squash ' .. revset .. ' into ' .. chosen_id .. ' ')
    end
  end)
end, { refresh = false })

M.abandon = with_revset(function(id)
  local utils = get_utils()
  vim.ui.select({ 'Yes', 'No' }, { prompt = 'Abandon ' .. id .. '?' }, function(choice)
    if choice == 'Yes' then
      utils.run_jj_cmd('abandon', id)
      utils.refresh_log()
    end
  end)
end, { refresh = false }) -- refresh handled in callback

M.bookmark = with_revset(function(id)
  local utils = get_utils()
  vim.ui.input({ prompt = 'Bookmark name: ' }, function(name)
    if name and name ~= '' then
      utils.run_jj_cmd('bookmark', 'set ' .. name .. ' -r ' .. id)
      utils.refresh_log()
    end
  end)
end, { refresh = false }) -- refresh handled in callback

M.rebase = with_revset(function(revset)
  local utils = get_utils()
  local destinations = utils.get_revisions()
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
      utils.run_jj_cmd('rebase', '-r ' .. revset .. ' -d ' .. dest_id)
      utils.run_jj_cmd 'rdev'
      utils.refresh_log()
    end
  end)
end, { refresh = false }) -- refresh handled in callback

function M.undo()
  local utils = get_utils()
  utils.run_jj_cmd('undo', '')
  utils.refresh_log()
end

function M.redo()
  local utils = get_utils()
  utils.run_jj_cmd('redo', '')
  utils.refresh_log()
end

--------------------------------------------------------------------------------
-- Navigation
--------------------------------------------------------------------------------

local function nav(direction)
  local state = get_state()
  local utils = get_utils()
  local preview = get_preview()

  vim.cmd('normal! 2' .. direction)

  -- Skip preview update if an async job is running
  if utils.has_active_job() then
    return
  end

  local revset = get_revset()
  if not revset then
    return
  end

  local cmd = is_visual() and 'diff' or 'show'
  local output = vim.fn.system(utils.build_jj_cmd(cmd .. ' -r ' .. revset .. ' --git'))
  preview.open(output, cmd, revset, { filetype = 'jujutsu', no_colorize = true })
end

function M.nav_down()
  nav 'j'
end

function M.nav_up()
  nav 'k'
end

--------------------------------------------------------------------------------
-- cdescribe (AI-generated description)
--------------------------------------------------------------------------------

M.cdescribe = with_revset(function(id)
  local state = get_state()
  local utils = get_utils()
  local CONST = get_const()

  local saved_cursor = is_win_valid(state.win) and vim.api.nvim_win_get_cursor(state.win) or nil

  -- Cancel any pending preview updates
  utils.cancel_debounce()

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

  local cmd = string.format('cd %s && cdescribe %s', vim.fn.shellescape(state.cwd), id)
  local job_id = vim.fn.termopen(cmd, {
    on_exit = function()
      vim.schedule(function()
        utils.clear_active_job()
        vim.cmd 'stopinsert'
        if vim.api.nvim_win_is_valid(win) then
          vim.api.nvim_win_close(win, true)
        end
        if is_win_valid(state.win) then
          vim.api.nvim_set_current_win(state.win)
        end
        utils.refresh_log(saved_cursor)
        if saved_cursor and is_win_valid(state.win) then
          pcall(vim.api.nvim_win_set_cursor, state.win, saved_cursor)
        end
      end)
    end,
  })

  if job_id > 0 then
    utils.set_active_job(job_id)
  end

  vim.cmd 'startinsert'
end, { refresh = false })

return M
