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
  vim.api.nvim_feedkeys(
    vim.api.nvim_replace_termcodes('<Esc>', true, false, true),
    'nx',
    false
  )
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
      local msg = was_visual and 'No change IDs found in selection'
        or 'No change ID found on this line'
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

local function find_and_jump_to_id(target_id)
  if not target_id then return end
  local state = get_state()
  local utils = get_utils()
  local preview = get_preview()
  if not is_buf_valid(state.buf) or not is_win_valid(state.win) then return end

  local lines = vim.api.nvim_buf_get_lines(state.buf, 0, -1, false)
  for i, line in ipairs(lines) do
    local line_id = utils.get_change_id_from_line(line)
    -- Target ID from `get_related_ids` is now the FULL change ID.
    -- `line_id` from the buffer is usually the short prefix (e.g. `qq`).
    -- So we check if the full target_id starts with the line_id, 
    -- OR if the line_id starts with the target_id (just in case).
    if line_id and (vim.startswith(target_id, line_id) or vim.startswith(line_id, target_id)) then
      pcall(vim.api.nvim_win_set_cursor, state.win, { i, 4 })
      vim.api.nvim_exec_autocmds('CursorMoved', { buffer = state.buf })

      -- Skip preview update if an async job is running
      if utils.has_active_job() then
        return true
      end

      local preview_type = is_visual() and 'diff' or 'show'
      vim.api.nvim_exec_autocmds('User', {
        pattern = 'JujutsuRevisionSelected',
        data = { id = line_id, type = preview_type },
      })

      return true
    end
  end
  vim.notify('Commit ' .. target_id .. ' not found in current log', vim.log.levels.INFO)
  return false
end

M.move_to_parent = with_revset(function(id)
  local utils = get_utils()
  local parent_id = utils.get_parent_id(id)
  if parent_id then
    find_and_jump_to_id(parent_id)
  else
    vim.notify('No parent found for ' .. id, vim.log.levels.WARN)
  end
end, { refresh = false })

M.move_to_child = with_revset(function(id)
  local utils = get_utils()
  local child_id = utils.get_child_id(id)
  if child_id then
    find_and_jump_to_id(child_id)
  else
    vim.notify('No child found for ' .. id, vim.log.levels.WARN)
  end
end, { refresh = false })

M.new = with_revset(function(id)
  local utils = get_utils()
  utils.run_jj_cmd('new', id)
end)

function M.new_current()
  local utils = get_utils()
  utils.run_jj_cmd('new', '')
  utils.refresh_log()
end

function M.new_dev()
  local utils = get_utils()
  -- Check if dev bookmark exists
  local output, success =
    utils.run_jj_cmd('bookmark list -r dev', nil, { notify = false })
  if success and output and vim.trim(output) ~= '' then
    utils.run_jj_cmd('new', 'dev')
    utils.refresh_log()
  end
  -- If dev doesn't exist, do nothing (no-op)
end

M.describe = with_revset(function(id)
  local utils = get_utils()
  utils.run_jj_with_editor('describe ' .. id, ' Describe ' .. id .. ' ')
end, { refresh = false }) -- refresh handled by editor callback

M.diff = with_revset(function(id)
  local utils = get_utils()
  vim.api.nvim_exec_autocmds('User', {
    pattern = 'JujutsuRevisionSelected',
    data = { id = id, type = 'diff' },
  })
end, { refresh = false })

M.show = with_revset(function(id)
  local state = get_state()
  local utils = get_utils()
  local preview = get_preview()

  if not state.win or not vim.api.nvim_win_is_valid(state.win) then
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(state.win)
  local win = state.win

  local preview_type = id:find '::' and 'diff' or 'show'
  vim.api.nvim_exec_autocmds('User', {
    pattern = 'JujutsuRevisionSelected',
    data = { id = id, type = preview_type },
  })

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

M.absorb = with_revset(function(id)
  local utils = get_utils()
  if id:find '::' then
    local newest = id:match '::(.+)$'
    utils.run_jj_cmd('absorb', string.format('-f %s -t %s', newest, id))
  else
    utils.run_jj_cmd('absorb', '-f ' .. id)
  end
end)

M.bookmark = with_revset(function(id)
  local utils = get_utils()
  vim.ui.input({ prompt = 'Bookmark name: ' }, function(name)
    if name and name ~= '' then
      utils.run_jj_cmd('bookmark', 'set ' .. name .. ' -r ' .. id)
      utils.refresh_log()
    end
  end)
end, { refresh = false }) -- refresh handled in callback

M.delete_bookmark = with_revset(function(revset)
  local utils = get_utils()
  local output, success = utils.run_jj_cmd(
    'bookmark list -r ' .. revset .. ' -T \'if(!self.remote(), self.name() ++ "\\n")\'',
    nil,
    { notify = false }
  )
  if not success then
    vim.notify('Failed to get bookmarks for ' .. revset, vim.log.levels.ERROR)
    return
  end
  local bookmarks = vim.split(vim.trim(output), '\n', { trimempty = true })
  if #bookmarks == 0 then
    vim.notify('No bookmark on ' .. revset, vim.log.levels.WARN)
    return
  end

  local function do_delete(bookmark)
    vim.ui.select(
      { 'Yes', 'No' },
      { prompt = 'Delete bookmark ' .. bookmark .. '?' },
      function(choice)
        if choice == 'Yes' then
          -- Check if it has a remote tracking bookmark before deleting
          local has_remote = false
          local remotes_out, remotes_success = utils.run_jj_cmd(
            'bookmark list '
              .. vim.fn.shellescape(bookmark)
              .. ' -a -T \'if(self.remote(), self.remote() ++ "\\n")\'',
            nil,
            { notify = false }
          )
          if remotes_success and remotes_out then
            for _, remote in
              ipairs(vim.split(vim.trim(remotes_out), '\n', { trimempty = true }))
            do
              if remote ~= 'git' and remote ~= '' then
                has_remote = true
                break
              end
            end
          end

          utils.run_jj_cmd('bookmark delete', vim.fn.shellescape(bookmark))
          utils.refresh_log()

          if has_remote then
            -- Give a small delay before showing the next prompt so the UI doesn't glitch
            vim.defer_fn(function()
              vim.ui.select(
                { 'Yes', 'No' },
                { prompt = 'Delete bookmark ' .. bookmark .. ' on remote too?' },
                function(push_choice)
                  if push_choice == 'Yes' then
                    utils.run_jj_cmd('git push', '-b ' .. vim.fn.shellescape(bookmark))
                    utils.refresh_log()
                  end
                end
              )
            end, 100)
          end
        end
      end
    )
  end

  if #bookmarks == 1 then
    do_delete(bookmarks[1])
  else
    vim.ui.select(bookmarks, { prompt = 'Select bookmark to delete:' }, function(choice)
      if choice then
        do_delete(choice)
      end
    end)
  end
end, { refresh = false })

M.forget_bookmark = with_revset(function(revset)
  local utils = get_utils()
  local output, success = utils.run_jj_cmd(
    'bookmark list -r ' .. revset .. ' -T \'if(!self.remote(), self.name() ++ "\\n")\'',
    nil,
    { notify = false }
  )
  if not success then
    vim.notify('Failed to get bookmarks for ' .. revset, vim.log.levels.ERROR)
    return
  end
  local bookmarks = vim.split(vim.trim(output), '\n', { trimempty = true })
  if #bookmarks == 0 then
    vim.notify('No bookmark on ' .. revset, vim.log.levels.WARN)
    return
  end

  local function do_forget(bookmark)
    vim.ui.select(
      { 'Yes', 'No' },
      { prompt = 'Forget bookmark ' .. bookmark .. '?' },
      function(choice)
        if choice == 'Yes' then
          utils.run_jj_cmd('bookmark forget', vim.fn.shellescape(bookmark))
          utils.refresh_log()
        end
      end
    )
  end

  if #bookmarks == 1 then
    do_forget(bookmarks[1])
  else
    vim.ui.select(bookmarks, { prompt = 'Select bookmark to forget:' }, function(choice)
      if choice then
        do_forget(choice)
      end
    end)
  end
end, { refresh = false })

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
-- Rebase
--------------------------------------------------------------------------------

local REBASE_MODES = {
  onto = { flag = '-d', desc = 'Onto (-d): make target the new parent' },
  before = { flag = '-B', desc = 'Before (-B): insert before target' },
  after = { flag = '-A', desc = 'After (-A): insert after target' },
}

--- Select a destination revision from trunk()::
---@param prompt string
---@param callback function(dest_id: string)
local function select_destination(prompt, callback)
  local utils = get_utils()
  local destinations = utils.get_revisions()
  if not destinations or #destinations == 0 then
    vim.notify('No destinations found from trunk()', vim.log.levels.WARN)
    return
  end
  vim.ui.select(destinations, { prompt = prompt }, function(choice)
    if choice then
      local dest_id = choice:match '^(%S+)'
      if dest_id then
        callback(dest_id)
      end
    end
  end)
end

--- Execute rebase with specified mode
---@param revset string
---@param target_id string
---@param mode 'onto'|'before'|'after'
local function do_rebase(revset, target_id, mode)
  local utils = get_utils()
  utils.run_jj_cmd(
    'rebase',
    '-r ' .. revset .. ' ' .. REBASE_MODES[mode].flag .. ' ' .. target_id
  )
  utils.run_jj_cmd 'rdev'
  utils.refresh_log()
end

M.rebase = with_revset(function(revset)
  select_destination('Rebase ' .. revset .. ' onto:', function(dest_id)
    do_rebase(revset, dest_id, 'onto')
  end)
end, { refresh = false })

M.rebase_before = with_revset(function(revset)
  select_destination('Rebase ' .. revset .. ' before:', function(dest_id)
    do_rebase(revset, dest_id, 'before')
  end)
end, { refresh = false })

-- Swap revision with its parent
M.switch_revisions = with_revset(function(id)
  local utils = get_utils()
  local parent_id = utils.get_parent_id(id)

  if not parent_id then
    vim.notify('Could not find parent of ' .. id, vim.log.levels.WARN)
    return
  end

  do_rebase(id, parent_id, 'before')
end, { refresh = false })

M.rebase_interactive = with_revset(function(revset)
  local modes = vim.tbl_map(function(key)
    return { mode = key, desc = REBASE_MODES[key].desc }
  end, { 'before', 'after', 'onto' })

  vim.ui.select(modes, {
    prompt = 'Rebase ' .. revset .. ':',
    format_item = function(item)
      return item.desc
    end,
  }, function(mode_choice)
    if not mode_choice then
      return
    end
    select_destination('Select target revision:', function(dest_id)
      do_rebase(revset, dest_id, mode_choice.mode)
    end)
  end)
end, { refresh = false })

M.duplicate = with_revset(function(revset)
  local modes = vim.tbl_map(function(key)
    return { mode = key, desc = REBASE_MODES[key].desc }
  end, { 'before', 'after', 'onto' })

  vim.ui.select(modes, {
    prompt = 'Duplicate ' .. revset .. ':',
    format_item = function(item)
      return item.desc
    end,
  }, function(mode_choice)
    if not mode_choice then
      return
    end
    select_destination('Select destination revision:', function(dest_id)
      local utils = get_utils()
      utils.run_jj_cmd(
        'duplicate',
        '-r ' .. revset .. ' ' .. REBASE_MODES[mode_choice.mode].flag .. ' ' .. dest_id
      )
      utils.refresh_log()
    end)
  end)
end, { refresh = false })

M.parallelize = with_revset(function(revset)
  local utils = get_utils()
  -- Check if revset contains '::' (range) indicating multiple revisions
  if not revset:find '::' then
    vim.notify(
      'Parallelize requires multiple revisions (use visual selection)',
      vim.log.levels.WARN
    )
    return
  end
  utils.run_jj_cmd('parallelize', revset)
end)

M.yank = with_revset(function(revset)
  vim.fn.setreg('+', revset)
  vim.notify('Yanked: ' .. revset)
end, { refresh = false })

M.yank_bookmark = with_revset(function(revset)
  local utils = get_utils()
  local output, success = utils.run_jj_cmd(
    'bookmark list -r ' .. revset .. ' -T \'if(!self.remote(), self.name() ++ "\\n")\'',
    nil,
    { notify = false }
  )
  if not success then
    vim.notify('Failed to get bookmarks for ' .. revset, vim.log.levels.ERROR)
    return
  end
  local bookmark = vim.trim(output):match '[^\n]+'
  if not bookmark or bookmark == '' then
    vim.notify('No bookmark on ' .. revset, vim.log.levels.WARN)
    return
  end
  vim.fn.setreg('+', bookmark)
  vim.notify('Yanked bookmark: ' .. bookmark)
end, { refresh = false })

--------------------------------------------------------------------------------
-- Navigation
--------------------------------------------------------------------------------

local function nav(direction)
  local state = get_state()
  local utils = get_utils()
  local preview = get_preview()

  local current_line = vim.fn.line('.')
  local last_line = vim.fn.line('$')
  local step = direction == 'j' and 1 or -1
  local target_line = current_line + step

  while target_line >= 1 and target_line <= last_line do
    local line_content = vim.fn.getline(target_line)
    if utils.get_change_id_from_line(line_content) then
      -- Jump to the line and explicitly set column to 4 (which is index 3) where the change ID usually starts.
      vim.fn.cursor(target_line, 4)
      break
    end
    target_line = target_line + step
  end

  -- Skip preview update if an async job is running
  if utils.has_active_job() then
    return
  end

  local revset = get_revset()
  if not revset then
    return
  end

  local preview_type = is_visual() and 'diff' or 'show'
  vim.api.nvim_exec_autocmds('User', {
    pattern = 'JujutsuRevisionSelected',
    data = { id = revset, type = preview_type },
  })
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

  -- Resolve revset to individual change IDs to avoid mangling descriptions
  -- of multiple revisions (jj describe -r <range> applies the same msg to all).
  local resolve_cmd = utils.build_jj_cmd(
    string.format("log -r %s --no-graph -T 'change_id ++ \"\\n\"'", vim.fn.shellescape(id))
  )
  local output = vim.fn.system(resolve_cmd)
  local ids = {}
  for line in output:gmatch '[^\n]+' do
    local cid = line:match '^%s*([k-z]+)%s*$'
    if cid then
      table.insert(ids, cid)
    end
  end

  if #ids == 0 then
    vim.notify('No revisions found for ' .. id, vim.log.levels.WARN, { title = 'Jujutsu' })
    return
  end

  -- Cancel any pending preview updates
  utils.cancel_debounce()

  local fidget_ok, fidget = pcall(require, 'fidget')
  local total = #ids
  local completed = 0

  for index, current_id in ipairs(ids) do
    local queued_msg = total > 1
        and string.format('Queued: %s (%d/%d)', current_id, index, total)
      or string.format('Queued: %s', current_id)
    local progress_handle = fidget_ok and fidget.progress.handle.create({
      title = 'Jujutsu',
      message = queued_msg,
      lsp_client = { name = 'cdescribe' },
    }) or nil

    utils.enqueue(function(on_done)
      local running_msg = total > 1
          and string.format('Generating description for %s (%d/%d)...', current_id, index, total)
        or string.format('Generating description for %s...', current_id)

      if progress_handle then
        progress_handle.message = running_msg
      else
        vim.notify(running_msg, vim.log.levels.INFO, { title = 'Jujutsu' })
      end

      vim.system({ 'cdescribe', current_id }, { cwd = state.cwd }, function(obj)
        vim.schedule(function()
          if progress_handle then
            progress_handle:finish()
          end
          if obj.code == 0 then
            if total == 1 then
              vim.notify('Generated description for ' .. current_id, vim.log.levels.INFO, { title = 'Jujutsu' })
            end
          else
            local err = (obj.stderr ~= '' and obj.stderr or obj.stdout) or 'unknown error'
            vim.notify(
              'Failed to generate description for ' .. current_id .. ': ' .. err,
              vim.log.levels.ERROR,
              { title = 'Jujutsu' }
            )
          end
          completed = completed + 1
          if completed == total then
            utils.refresh_log()
            if total > 1 then
              vim.notify(
                string.format('Finished generating %d descriptions.', total),
                vim.log.levels.INFO,
                { title = 'Jujutsu' }
              )
            end
          end
          on_done()
        end)
      end)
    end)
  end
end, { refresh = false })

--------------------------------------------------------------------------------
-- Split revision
--------------------------------------------------------------------------------

M.split = with_revset(function(id)
  local state = get_state()
  local utils = get_utils()

  -- Open new tab for the split terminal
  vim.cmd 'tabnew'

  local cmd = string.format('cd %s && jj split -r %s', vim.fn.shellescape(state.cwd), id)
  local job_id = vim.fn.termopen(cmd, {
    on_exit = function(_, exit_code)
      vim.schedule(function()
        utils.clear_active_job()
        -- Close terminal tab after brief delay to show result
        vim.defer_fn(function()
          -- Only close if still on the terminal buffer
          if vim.bo.buftype == 'terminal' then
            vim.cmd 'bdelete!'
          end
          utils.refresh_log()
        end, exit_code == 0 and 500 or 2000) -- Longer delay on error
      end)
    end,
  })

  if job_id > 0 then
    utils.set_active_job(job_id)
  end

  vim.cmd 'startinsert'
end, { refresh = false })

--------------------------------------------------------------------------------
-- Git push
--------------------------------------------------------------------------------

local function get_bookmarks(revset)
  local utils = get_utils()
  local template =
    [[if(!self.remote(), self.normal_target().change_id().shortest() ++ " " ++ self.name() ++ if(!self.synced(), "*", "") ++ " " ++ self.normal_target().commit_id().shortest() ++ "\n")]]
  local target_revset = revset or 'trunk():: ~ dev ~ trunk()'
  local cmd = 'bookmark list -r '
    .. vim.fn.shellescape(target_revset)
    .. ' -T '
    .. vim.fn.shellescape(template)
  local output, success = utils.run_jj_cmd(cmd, nil, { notify = false })
  if not success then
    return nil
  end
  local lines = vim.split(output, '\n', { trimempty = true })
  return #lines > 0 and lines or nil
end

function M.push()
  local utils = get_utils()
  utils.run_jj_cmd('git push --tracked', '')
  utils.refresh_log()
end

function M.fetch()
  local utils = get_utils()
  utils.run_jj_cmd('git fetch', '')
  utils.refresh_log()
end

local function move_bookmark_impl(opts)
  opts = opts or {}
  return with_revset(function(id)
    local utils = get_utils()
    local bookmarks = get_bookmarks()
    if not bookmarks or #bookmarks == 0 then
      vim.notify('No bookmarks found from trunk()..', vim.log.levels.WARN)
      return
    end

    vim.ui.select(bookmarks, {
      prompt = 'Move bookmark to ' .. id .. ':',
      format_item = function(item)
        return item
      end,
    }, function(choice)
      if not choice then
        return
      end
      local bookmark_name = choice:match '^%S+%s+(%S+)'
      if bookmark_name then
        bookmark_name = bookmark_name:gsub('%*$', '')
        local args = bookmark_name .. ' -t ' .. id
        if opts.allow_backwards then
          args = args .. ' --allow-backwards'
        end
        utils.run_jj_cmd('bookmark move', args)
        utils.run_jj_cmd 'rdev'
        utils.refresh_log()
      end
    end)
  end, { refresh = false })
end

M.move_bookmark = move_bookmark_impl

M.push_bookmark = with_revset(function(id)
  local utils = get_utils()
  local bookmarks = get_bookmarks(id)
  if not bookmarks or #bookmarks == 0 then
    vim.notify('No bookmarks found for the selected revision.', vim.log.levels.WARN)
    return
  end

  local function do_push(choice)
    local bookmark_name = choice:match '^%S+%s+(%S+)'
    if bookmark_name then
      -- Remove trailing * if present (indicates unsynced)
      bookmark_name = bookmark_name:gsub('%*$', '')
      utils.run_jj_cmd('git push', '-b ' .. bookmark_name)
      utils.refresh_log()
    end
  end

  if #bookmarks == 1 then
    do_push(bookmarks[1])
  else
    vim.ui.select(bookmarks, {
      prompt = 'Push bookmark:',
      format_item = function(item)
        return item
      end,
    }, function(choice)
      if not choice then
        return
      end
      do_push(choice)
    end)
  end
end)

M.move_trunk_bookmark = with_revset(function(id)
  local utils = get_utils()
  utils.run_jj_cmd('bookmark move', '--from "trunk()" -t ' .. id)
  utils.run_jj_cmd 'rdev'
  utils.refresh_log()
end, { refresh = false })

return M
