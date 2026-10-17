-- vim: ts=2 sts=2 sw=2 et
local M = {}

M.setup = function() end

M.simple_tabline = function()
  local s = '' -- Initialize the output string
  local current_tab = vim.fn.tabpagenr()
  local num_tabs = vim.fn.tabpagenr '$'

  -- Get colors from the existing highlight groups
  local function get_hl_colors(group)
    local hl = vim.api.nvim_get_hl(0, { name = group, link = false })
    return {
      fg = hl.fg and string.format('#%06x', hl.fg) or 'NONE',
      bg = hl.bg and string.format('#%06x', hl.bg) or 'NONE',
    }
  end

  local tab_sel_colors = get_hl_colors 'TabLineSel'
  local tab_line_colors = get_hl_colors 'TabLine'
  local tab_fill_colors = get_hl_colors 'TabLineFill'

  -- Function to count unique normal buffers in a tab
  local function count_normal_buffers(tab_idx)
    local buflist = vim.fn.tabpagebuflist(tab_idx)
    local unique_buffers = {}
    local count = 0

    for _, buf_id in ipairs(buflist) do
      -- Only count each buffer once
      if not unique_buffers[buf_id] and vim.api.nvim_buf_is_valid(buf_id) then
        local buftype = vim.bo[buf_id].buftype
        local bufhidden = vim.bo[buf_id].bufhidden

        -- Count only normal buffers (not special buffers)
        if buftype == '' and bufhidden ~= 'hide' then
          count = count + 1
          unique_buffers[buf_id] = true
        end
      end
    end

    return count
  end

  for i = 1, num_tabs do
    local is_selected = i == current_tab
    local tab_hl = is_selected and 'TabLineSel' or 'TabLine'
    local bg = is_selected and tab_sel_colors.bg or tab_line_colors.bg

    local next_is_selected = (i + 1) == current_tab
    local next_bg = tab_fill_colors.bg
    if i < num_tabs then
      next_bg = next_is_selected and tab_sel_colors.bg or tab_line_colors.bg
    end

    -- Leading arrow only for the first tab
    if i == 1 then
      vim.cmd('highlight TabLineSepFirst guifg=' .. tab_fill_colors.bg .. ' guibg=' .. bg)
      s = s .. '%#TabLineFill# %#TabLineSepFirst#'
    end

    -- Add tab content with normal tab highlight
    s = s .. '%#' .. tab_hl .. '#'

    -- Get buffer list for the tab and the active window in that tab
    local buflist = vim.fn.tabpagebuflist(i)
    local winnr = vim.fn.tabpagewinnr(i)
    local bufnr = buflist[winnr]

    -- Get unique normal buffer count
    local normal_buffer_count = count_normal_buffers(i)

    -- Get buffer name and extract filename (tail)
    local bufpath = vim.fn.bufname(bufnr)
    local filename = vim.fn.fnamemodify(bufpath, ':t')

    -- Handle buffers without a name
    if filename == '' then
      -- Check if buffer ID is valid before accessing buffer-local options
      local buftype = ''
      if bufnr and bufnr > 0 and vim.api.nvim_buf_is_valid(bufnr) then
        buftype = vim.bo[bufnr].buftype
      end

      if buftype == 'quickfix' then
        filename = '[Quickfix]'
      elseif buftype == 'help' then
        filename = '[Help]'
      elseif buftype == 'terminal' then
        filename = '[Terminal]'
      else
        filename = '[No Name]'
      end
    end

    -- Add the filename with buffer and window count
    if normal_buffer_count > 1 then
      s = s .. ' ' .. filename .. ' [' .. normal_buffer_count .. '] '
    else
      s = s .. ' ' .. filename .. ' '
    end

    -- Add right symbol with appropriate highlight
    local sep_hl = 'TabLineSep' .. i
    vim.cmd('highlight ' .. sep_hl .. ' guifg=' .. bg .. ' guibg=' .. next_bg)
    s = s .. '%#' .. sep_hl .. '#'
  end

  -- Fill the rest of the line
  s = s .. '%#TabLineFill#%='

  return s
end

M.rsync_current_file = function(destination, opts)
  -- Set default options
  opts = opts or {}
  local rsync_flags = opts.flags or '-avz'

  -- Get the current buffer's file path
  local filepath = vim.api.nvim_buf_get_name(0)

  if filepath == '' then
    vim.notify('Current buffer has no file', vim.log.levels.ERROR)
    return false
  end

  -- Check if file exists
  if vim.fn.filereadable(filepath) == 0 then
    vim.notify('File not readable: ' .. filepath, vim.log.levels.ERROR)
    return false
  end

  -- If no destination provided, prompt for one
  if not destination or destination == '' then
    destination = vim.fn.input 'Rsync destination (user@host:path): '
    if destination == '' then
      vim.notify('No destination provided', vim.log.levels.WARN)
      return false
    end
  end

  -- Construct the rsync command
  local cmd = { 'rsync', rsync_flags, filepath, destination }

  vim.notify(
    'Syncing ' .. filepath .. ' to ' .. destination .. '...',
    vim.log.levels.INFO
  )

  -- Execute rsync
  vim.system(
    cmd,
    { text = true },
    vim.schedule_wrap(function(obj)
      if obj.code == 0 then
        vim.notify('File synced successfully to ' .. destination, vim.log.levels.INFO)
      else
        vim.notify(
          'Rsync failed: ' .. (obj.stderr or 'Unknown error'),
          vim.log.levels.ERROR
        )
      end
    end)
  )

  return true
end

M.open_url = function(url)
  local container_name = os.getenv 'CONTAINER_ID'
  local cmd = string.format('xdg-open %s', url)

  if container_name then
    cmd = string.format('gtk-launch %s-google-chrome.desktop "%s"', container_name, url)
  end

  vim.notify('Opening URL: ' .. url, vim.log.levels.INFO)
  vim.fn.jobstart(cmd)
  vim.notify('Opening in browser: ' .. url, vim.log.levels.INFO)
end

local showme_annotations = {}
local active_tour
local presentation
local feedback_reports = {}
local feedback_report_order = {}
local active_report
local comment_editor
local close_comment_editor
local feedback_counter = 0
local stop_tour
local finalize_active_report
local close_presentation
local validate_tour_options
local configure_presentation_mappings
local ensure_presentation_lifecycle
local restore_presentation_mappings
local clear_showme_annotation
local cleanup_closed_presentation

local function require_showme_namespace_support()
  if type(vim.api.nvim__ns_set) ~= 'function' then
    error 'ShowMe/ClearShowMe require Neovim with nvim__ns_set window-scoped namespaces.'
  end
end

local function presentation_windows(state)
  if not state or not vim.api.nvim_tabpage_is_valid(state.tabpage) then
    error 'ShowMe presentation tab is no longer available.'
  end

  local windows = {}
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(state.tabpage)) do
    local config = vim.api.nvim_win_get_config(win)
    if config.relative == '' and vim.bo[vim.api.nvim_win_get_buf(win)].buftype == '' then
      table.insert(windows, win)
    end
  end
  if #windows ~= 2 then
    error 'ShowMe presentation tab requires its original two side-by-side windows.'
  end

  local left_position = vim.api.nvim_win_get_position(windows[1])
  local right_position = vim.api.nvim_win_get_position(windows[2])
  if left_position[1] ~= right_position[1] or left_position[2] == right_position[2] then
    error 'ShowMe presentation tab requires its original two side-by-side windows.'
  end
  table.sort(windows, function(left, right)
    return vim.api.nvim_win_get_position(left)[2]
      < vim.api.nvim_win_get_position(right)[2]
  end)
  return windows
end

local function create_presentation()
  local origin_tabpage = vim.api.nvim_get_current_tabpage()
  local origin_window = vim.api.nvim_get_current_win()
  vim.cmd 'tabnew'
  vim.cmd 'vsplit'
  presentation = {
    tabpage = vim.api.nvim_get_current_tabpage(),
    origin_tabpage = origin_tabpage,
    origin_window = origin_window,
    mappings = {},
    mappings_installed = false,
    presented_buffers = {},
  }
  presentation.windows = presentation_windows(presentation)
  if ensure_presentation_lifecycle then
    ensure_presentation_lifecycle()
  end
  return presentation.windows
end

local function ensure_presentation()
  if presentation and vim.api.nvim_tabpage_is_valid(presentation.tabpage) then
    local windows = presentation_windows(presentation)
    vim.api.nvim_set_current_tabpage(presentation.tabpage)
    presentation.windows = windows
    return windows
  end
  if presentation then
    cleanup_closed_presentation(presentation)
  end
  return create_presentation()
end

local function validate_showme(filename, inclusive_1_based_range, message, side)
  if
    type(filename) ~= 'string'
    or filename == ''
    or vim.fn.filereadable(filename) ~= 1
  then
    error 'ShowMe filename must name a readable file.'
  end
  if type(inclusive_1_based_range) ~= 'table' or #inclusive_1_based_range ~= 2 then
    error 'ShowMe range must be a two-item inclusive 1-based range.'
  end

  local first, last = inclusive_1_based_range[1], inclusive_1_based_range[2]
  if
    type(first) ~= 'number'
    or first % 1 ~= 0
    or type(last) ~= 'number'
    or last % 1 ~= 0
    or first < 1
    or last < first
  then
    error 'ShowMe range must be a valid inclusive 1-based range.'
  end
  if type(message) ~= 'string' then
    error 'ShowMe message must be plain text.'
  end
  if side ~= 'left' and side ~= 'right' then
    error "ShowMe side must be 'left' or 'right'."
  end
  return first, last
end

local function showme_buffer(filename)
  local path = vim.fn.fnamemodify(filename, ':p')
  local buffer = vim.fn.bufnr(path)
  if buffer == -1 then
    buffer = vim.fn.bufadd(path)
  end
  if not vim.api.nvim_buf_is_loaded(buffer) then
    local ok, load_error = pcall(vim.fn.bufload, buffer)
    if not ok then
      error('ShowMe could not load file: ' .. load_error)
    end
  end
  return buffer
end

local function safely_set_showme_buffer(window, buffer)
  local previous = vim.api.nvim_win_get_buf(window)
  if previous == buffer then
    return
  end

  local restore_bufhidden
  local visible = 0
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == previous then
      visible = visible + 1
    end
  end
  if visible == 1 then
    restore_bufhidden = vim.bo[previous].bufhidden
    vim.bo[previous].bufhidden = 'hide'
  end

  local ok, set_error = pcall(vim.api.nvim_win_set_buf, window, buffer)
  if restore_bufhidden and vim.api.nvim_buf_is_valid(previous) then
    vim.bo[previous].bufhidden = restore_bufhidden
  end
  if not ok then
    error('ShowMe could not display file: ' .. set_error)
  end
end

local generated_showme_highlights = {}

local function showme_highlight(name)
  return vim.api.nvim_get_hl(0, { name = name, link = true, create = false })
end

local function showme_default_is_owned(name)
  local highlight = showme_highlight(name)
  local generated = generated_showme_highlights[name]
  return next(highlight) == nil
    or (generated ~= nil and vim.deep_equal(highlight, generated))
end

local function set_showme_default(name, highlight)
  vim.api.nvim_set_hl(0, name, highlight)
  generated_showme_highlights[name] = showme_highlight(name)
end

local function define_showme_highlights()
  if showme_default_is_owned 'MiscShowMeBackground' then
    local cursorline = vim.api.nvim_get_hl(0, {
      name = 'CursorLine',
      link = false,
      create = false,
    })
    local background = { default = true, force = true }
    if cursorline.bg then
      background.bg = cursorline.bg
    end
    if cursorline.ctermbg then
      background.ctermbg = cursorline.ctermbg
    end
    set_showme_default('MiscShowMeBackground', background)
  end
  if showme_default_is_owned 'MiscShowMeMessage' then
    set_showme_default('MiscShowMeMessage', {
      default = true,
      force = true,
      link = 'DiagnosticVirtualTextInfo',
    })
  end
end

local function split_showme_word(word, width)
  local lines = {}
  local line = ''
  for index = 0, vim.fn.strchars(word) - 1 do
    local character = vim.fn.strcharpart(word, index, 1)
    if line ~= '' and vim.fn.strdisplaywidth(line .. character) > width then
      table.insert(lines, line)
      line = character
    else
      line = line .. character
    end
  end
  table.insert(lines, line)
  return lines
end

local function wrap_showme_message(message, width)
  local lines = {}
  for paragraph in (message .. '\n'):gmatch '(.-)\n' do
    local line = ''
    for word in paragraph:gmatch '%S+' do
      if vim.fn.strdisplaywidth(word) > width then
        if line ~= '' then
          table.insert(lines, line)
          line = ''
        end
        local fragments = split_showme_word(word, width)
        for index = 1, #fragments - 1 do
          table.insert(lines, fragments[index])
        end
        line = fragments[#fragments]
      else
        local candidate = line == '' and word or line .. ' ' .. word
        if line ~= '' and vim.fn.strdisplaywidth(candidate) > width then
          table.insert(lines, line)
          line = word
        else
          line = candidate
        end
      end
    end
    table.insert(lines, line)
  end
  return lines
end

local function live_showme_range(annotation)
  if not vim.api.nvim_buf_is_valid(annotation.buffer) then
    return
  end
  local first, last
  local marks = vim.api.nvim_buf_get_extmarks(
    annotation.buffer,
    annotation.namespace,
    0,
    -1,
    { details = true }
  )
  for _, mark in ipairs(marks) do
    if mark[4].line_hl_group then
      local line = mark[2] + 1
      first = first and math.min(first, line) or line
      last = last and math.max(last, line) or line
    end
  end
  if first and last <= vim.api.nvim_buf_line_count(annotation.buffer) then
    return first, last
  end
end

local function range_comment(report, entry_key)
  for index, comment in ipairs(report.comments) do
    if comment.entry_key == entry_key then
      return comment, index
    end
  end
end

local function render_showme_annotation(annotation)
  if
    not vim.api.nvim_buf_is_valid(annotation.buffer)
    or not vim.api.nvim_win_is_valid(annotation.window)
    or vim.api.nvim_win_get_buf(annotation.window) ~= annotation.buffer
    or annotation.last > vim.api.nvim_buf_line_count(annotation.buffer)
  then
    if vim.api.nvim_buf_is_valid(annotation.buffer) then
      vim.api.nvim_buf_clear_namespace(annotation.buffer, annotation.namespace, 0, -1)
    end
    return false
  end

  vim.api.nvim__ns_set(annotation.namespace, { wins = { annotation.window } })
  vim.api.nvim_buf_clear_namespace(annotation.buffer, annotation.namespace, 0, -1)
  local window_info = vim.fn.getwininfo(annotation.window)[1]
  local width =
    math.max(1, vim.api.nvim_win_get_width(annotation.window) - window_info.textoff)
  for line = annotation.first, annotation.last do
    vim.api.nvim_buf_set_extmark(annotation.buffer, annotation.namespace, line - 1, 0, {
      line_hl_group = 'MiscShowMeBackground',
    })
  end

  local virtual_lines = {}
  local message = annotation.message
  if annotation.report then
    local comment = range_comment(annotation.report, annotation.entry_key)
    if comment then
      message = message .. '\n\nComment:\n' .. comment.message
    end
  end
  message = message .. (annotation.footer or '')
  for _, line in ipairs(wrap_showme_message(message, width)) do
    local padding = math.max(0, width - vim.fn.strdisplaywidth(line))
    table.insert(
      virtual_lines,
      { { line .. string.rep(' ', padding), 'MiscShowMeMessage' } }
    )
  end
  vim.api.nvim_buf_set_extmark(
    annotation.buffer,
    annotation.namespace,
    annotation.last - 1,
    0,
    { virt_lines = virtual_lines }
  )
  return true
end

local showme_augroup

local function configure_showme_autocommands()
  if showme_augroup then
    return
  end

  showme_augroup = vim.api.nvim_create_augroup('misc-showme', { clear = true })
  vim.api.nvim_create_autocmd({ 'VimResized', 'WinResized' }, {
    group = showme_augroup,
    callback = function()
      local stale_sides = {}
      for side, annotation in pairs(showme_annotations) do
        if not render_showme_annotation(annotation) then
          table.insert(stale_sides, side)
        end
      end
      for _, side in ipairs(stale_sides) do
        showme_annotations[side] = nil
      end
    end,
  })
  vim.api.nvim_create_autocmd('ColorScheme', {
    group = showme_augroup,
    callback = define_showme_highlights,
  })
end

clear_showme_annotation = function(side)
  local annotation = showme_annotations[side]
  if annotation and vim.api.nvim_buf_is_valid(annotation.buffer) then
    vim.api.nvim_buf_clear_namespace(annotation.buffer, annotation.namespace, 0, -1)
  end
  showme_annotations[side] = nil
end

local function new_feedback_report(kind)
  feedback_counter = feedback_counter + 1
  local clock = (vim.uv or vim.loop).hrtime()
  local report = {
    id = string.format('%s-%d-%d-%d', kind, vim.fn.getpid(), clock, feedback_counter),
    kind = kind,
    status = 'active',
    comments = {},
  }
  feedback_reports[report.id] = report
  table.insert(feedback_report_order, report.id)
  active_report = report
  return report
end

finalize_active_report = function(ended_by, report)
  report = report or active_report
  if not report or report.status ~= 'active' then
    return false
  end
  if comment_editor and comment_editor.report == report then
    close_comment_editor(comment_editor)
  end
  report.status = 'completed'
  report.ended_by = ended_by
  if active_report == report then
    active_report = nil
  end
  return true
end

local function copy_feedback_report(report)
  local comments = {}
  for index, comment in ipairs(report.comments) do
    comments[index] = {
      report_id = comment.report_id,
      kind = comment.kind,
      step = comment.step,
      side = comment.side,
      filename = comment.filename,
      range = { first = comment.range.first, last = comment.range.last },
      message = comment.message,
      excerpt = comment.excerpt,
    }
  end
  return {
    id = report.id,
    kind = report.kind,
    status = report.status,
    ended_by = report.ended_by,
    comments = comments,
  }
end

local function cleanup_invalid_presentation()
  if presentation and not vim.api.nvim_tabpage_is_valid(presentation.tabpage) then
    cleanup_closed_presentation(presentation)
  end
end

M.GetTourComments = function(report_id)
  if report_id ~= nil and type(report_id) ~= 'string' then
    error 'GetTourComments report ID must be a string.'
  end
  cleanup_invalid_presentation()
  local reports = {}
  for _, id in ipairs(feedback_report_order) do
    local report = feedback_reports[id]
    if
      report.status == 'completed'
      and not report.acknowledged
      and #report.comments > 0
      and (report_id == nil or report.id == report_id)
    then
      table.insert(reports, copy_feedback_report(report))
    end
  end
  return reports
end

M.AcknowledgeTourComments = function(report_id)
  if type(report_id) ~= 'string' then
    error 'AcknowledgeTourComments report ID must be a string.'
  end
  cleanup_invalid_presentation()
  local report = feedback_reports[report_id]
  if not report or report.status ~= 'completed' then
    return false
  end
  report.acknowledged = true
  return true
end

local function display_showme_entry(entry, side, windows)
  local target = side == 'left' and windows[1] or windows[2]
  safely_set_showme_buffer(target, entry.buffer)
  vim.api.nvim_win_call(target, function()
    for line = entry.first, entry.last do
      vim.api.nvim_win_set_cursor(target, { line, 0 })
      vim.cmd 'normal! zv'
    end
    vim.api.nvim_win_set_cursor(target, { entry.first, 0 })
    local scrolloff = vim.wo[target].scrolloff
    vim.wo[target].scrolloff = 0
    vim.cmd 'normal! zt'
    vim.wo[target].scrolloff = scrolloff
  end)

  local annotation = showme_annotations[side]
  if not annotation then
    annotation = {
      namespace = vim.api.nvim_create_namespace('misc-showme-' .. side),
    }
  elseif vim.api.nvim_buf_is_valid(annotation.buffer) then
    vim.api.nvim_buf_clear_namespace(annotation.buffer, annotation.namespace, 0, -1)
  end

  annotation.buffer = entry.buffer
  annotation.window = target
  if presentation then
    presentation.presented_buffers[entry.buffer] = true
  end
  annotation.first = entry.first
  annotation.last = entry.last
  annotation.message = entry.message
  annotation.entry_key = table.concat({
    vim.api.nvim_buf_get_name(entry.buffer),
    tostring(entry.first),
    tostring(entry.last),
  }, '\0')
  annotation.footer = entry.footer
  annotation.report = entry.report
  annotation.step = entry.step
  annotation.side = side
  showme_annotations[side] = annotation
  define_showme_highlights()
  configure_showme_autocommands()
  render_showme_annotation(annotation)
end

local function submit_showme_comment(snapshot, message)
  if type(message) ~= 'string' or vim.trim(message) == '' then
    return false
  end
  local report = snapshot.report
  if active_report ~= report or report.status ~= 'active' then
    vim.notify(
      'ShowMe comment was not saved because its presentation ended.',
      vim.log.levels.WARN
    )
    return false
  end
  local _, index = range_comment(report, snapshot.entry_key)
  report.comments[index or (#report.comments + 1)] = {
    report_id = report.id,
    kind = report.kind,
    step = snapshot.step,
    side = snapshot.side,
    entry_key = snapshot.entry_key,
    filename = snapshot.filename,
    range = { first = snapshot.first, last = snapshot.last },
    message = message,
    excerpt = snapshot.excerpt,
  }
  for _, annotation in pairs(showme_annotations) do
    if annotation.report == report and annotation.entry_key == snapshot.entry_key then
      local first, last = live_showme_range(annotation)
      if first then
        annotation.first, annotation.last = first, last
      end
      render_showme_annotation(annotation)
    end
  end
  return true
end

local function comment_editor_geometry()
  local width = math.max(1, math.min(100, vim.o.columns - 4))
  local height = math.max(1, math.min(math.floor(vim.o.lines / 2), vim.o.lines - 4))
  return {
    relative = 'editor',
    width = width,
    height = height,
    row = math.max(0, math.floor((vim.o.lines - height - 2) / 2)),
    col = math.max(0, math.floor((vim.o.columns - width - 2) / 2)),
  }
end

close_comment_editor = function(editor, window_closed)
  if comment_editor ~= editor then
    return
  end
  comment_editor = nil
  local was_current = vim.api.nvim_get_current_win() == editor.window
  if was_current then
    vim.cmd 'stopinsert'
  end
  pcall(vim.api.nvim_del_augroup_by_id, editor.augroup)
  local restore_focus = not window_closed and was_current
  if not window_closed and vim.api.nvim_win_is_valid(editor.window) then
    vim.api.nvim_win_close(editor.window, true)
  end
  local function wipe_buffer()
    if vim.api.nvim_buf_is_valid(editor.buffer) then
      vim.api.nvim_buf_delete(editor.buffer, { force = true })
    end
  end
  if window_closed then
    vim.schedule(wipe_buffer)
  else
    wipe_buffer()
  end
  if restore_focus and vim.api.nvim_win_is_valid(editor.origin_window) then
    vim.api.nvim_set_current_win(editor.origin_window)
  end
end

local function open_comment_editor(snapshot, origin_window)
  if comment_editor then
    if vim.api.nvim_win_is_valid(comment_editor.window) then
      vim.api.nvim_set_current_win(comment_editor.window)
      return
    end
    close_comment_editor(comment_editor, true)
  end
  local buffer = vim.api.nvim_create_buf(false, true)
  vim.bo[buffer].bufhidden = 'wipe'
  vim.bo[buffer].swapfile = false
  vim.bo[buffer].filetype = 'markdown'
  vim.bo[buffer].textwidth = 0
  local comment = range_comment(snapshot.report, snapshot.entry_key)
  local lines = comment and vim.split(comment.message, '\n', { plain = true }) or { '' }
  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, lines)
  local config = comment_editor_geometry()
  config.border = 'rounded'
  config.style = 'minimal'
  config.title = string.format(
    ' %s:%d-%d | normal: <CR> save, q cancel ',
    vim.fn.fnamemodify(snapshot.filename, ':t'),
    snapshot.first,
    snapshot.last
  )
  config.title_pos = 'center'
  local ok, window = pcall(vim.api.nvim_open_win, buffer, true, config)
  if not ok then
    vim.api.nvim_buf_delete(buffer, { force = true })
    error(window)
  end
  vim.wo[window].wrap = true
  vim.wo[window].linebreak = true
  vim.api.nvim_win_set_cursor(window, { #lines, #lines[#lines] })
  local editor = {
    buffer = buffer,
    window = window,
    origin_window = origin_window,
    report = snapshot.report,
    augroup = vim.api.nvim_create_augroup('misc-showme-comment-editor', { clear = true }),
  }
  comment_editor = editor
  vim.api.nvim_create_autocmd('WinClosed', {
    group = editor.augroup,
    pattern = tostring(window),
    once = true,
    callback = function()
      close_comment_editor(editor, true)
    end,
  })
  vim.api.nvim_create_autocmd('TabLeave', {
    group = editor.augroup,
    callback = function()
      if comment_editor == editor and vim.api.nvim_get_current_win() == window then
        vim.cmd 'stopinsert'
      end
    end,
  })
  vim.api.nvim_create_autocmd('VimResized', {
    group = editor.augroup,
    callback = function()
      if comment_editor == editor and vim.api.nvim_win_is_valid(window) then
        vim.api.nvim_win_set_config(window, comment_editor_geometry())
      end
    end,
  })
  vim.keymap.set('n', '<CR>', function()
    local text = table.concat(vim.api.nvim_buf_get_lines(buffer, 0, -1, false), '\n')
    close_comment_editor(editor)
    submit_showme_comment(snapshot, text)
  end, { buffer = buffer, nowait = true, silent = true })
  vim.keymap.set('n', 'q', function()
    close_comment_editor(editor)
  end, { buffer = buffer, nowait = true, silent = true })
  vim.cmd 'startinsert!'
end

M.AnnotateShowMe = function(message)
  if message ~= nil and type(message) ~= 'string' then
    error 'AnnotateShowMe message must be plain text.'
  end
  cleanup_invalid_presentation()
  local state = presentation
  if not state or vim.api.nvim_get_current_tabpage() ~= state.tabpage then
    return false
  end
  local current_window = vim.api.nvim_get_current_win()
  local annotation
  for _, side in ipairs { 'left', 'right' } do
    if showme_annotations[side] and showme_annotations[side].window == current_window then
      annotation = showme_annotations[side]
      break
    end
  end
  if
    not annotation
    or not annotation.report
    or annotation.report ~= active_report
    or annotation.report.status ~= 'active'
    or not vim.api.nvim_buf_is_valid(annotation.buffer)
    or vim.api.nvim_win_get_buf(current_window) ~= annotation.buffer
  then
    return false
  end
  local first, last = live_showme_range(annotation)
  if not first then
    return false
  end
  annotation.first, annotation.last = first, last
  local snapshot = {
    report = annotation.report,
    step = annotation.step,
    side = annotation.side,
    entry_key = annotation.entry_key,
    filename = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(annotation.buffer), ':p'),
    first = annotation.first,
    last = annotation.last,
    excerpt = table.concat(
      vim.api.nvim_buf_get_lines(
        annotation.buffer,
        annotation.first - 1,
        annotation.last,
        false
      ),
      '\n'
    ),
  }
  if message ~= nil then
    return submit_showme_comment(snapshot, message)
  end
  open_comment_editor(snapshot, current_window)
  return true
end

M.ShowMe = function(filename, inclusive_1_based_range, message, side)
  require_showme_namespace_support()
  local first, last = validate_showme(filename, inclusive_1_based_range, message, side)
  local buffer = showme_buffer(vim.fn.fnamemodify(filename, ':p'))
  if last > vim.api.nvim_buf_line_count(buffer) then
    error 'ShowMe range extends beyond the end of the file.'
  end
  local standalone_keys = validate_tour_options(nil)
  local windows = ensure_presentation()

  if active_tour then
    stop_tour 'interrupted'
  elseif active_report and active_report.kind ~= 'showme' then
    finalize_active_report('replaced', active_report)
  end
  local report = active_report
  local continuing = report ~= nil
  if not report then
    report = new_feedback_report 'showme'
  end
  restore_presentation_mappings(presentation)
  if not continuing then
    presentation.keys = standalone_keys
  end
  presentation.tour = nil
  presentation.report = report
  display_showme_entry({
    buffer = buffer,
    first = first,
    last = last,
    message = message,
    report = report,
    step = 1,
  }, side, windows)
  if configure_presentation_mappings then
    configure_presentation_mappings()
  end
  return report.id
end

M.ClearShowMe = function(side)
  require_showme_namespace_support()
  if side ~= nil and side ~= 'left' and side ~= 'right' then
    error "ClearShowMe side must be 'left' or 'right'."
  end

  if active_tour then
    stop_tour 'cleared'
    restore_presentation_mappings(presentation)
    presentation.keys = validate_tour_options(nil)
    configure_presentation_mappings()
  end
  if side then
    clear_showme_annotation(side)
  else
    clear_showme_annotation 'left'
    clear_showme_annotation 'right'
  end
end

local default_tour_keys = {
  next = ']t',
  prev = '[t',
  stop = '<leader>tq',
  annotate = '<leader>ta',
}

local function expand_tour_key(key)
  local leader = vim.g.mapleader or '\\'
  local localleader = vim.g.maplocalleader or '\\'
  local expanded = key:gsub('<[Ll][Oo][Cc][Aa][Ll][Ll][Ee][Aa][Dd][Ee][Rr]>', function()
    return localleader
  end)
  return expanded:gsub('<[Ll][Ee][Aa][Dd][Ee][Rr]>', function()
    return leader
  end)
end

validate_tour_options = function(options)
  if options ~= nil and type(options) ~= 'table' then
    error 'Tour options must be a table.'
  end

  local configured = vim.deepcopy(default_tour_keys)
  for name, key in pairs(options or {}) do
    if name ~= 'next' and name ~= 'prev' and name ~= 'stop' and name ~= 'annotate' then
      error 'Tour options only accept next, prev, stop, and annotate keys.'
    end
    if type(key) ~= 'string' or key == '' then
      error 'Tour navigation keys must be non-empty strings.'
    end
    configured[name] = key
  end

  local keys = {}
  for name, key in pairs(configured) do
    local lhs = vim.keycode(expand_tour_key(key))
    for other_name, other_key in pairs(keys) do
      if lhs == other_key.lhs then
        error(
          'Tour navigation keys must not collide: '
            .. name
            .. ' and '
            .. other_name
            .. '.'
        )
      end
    end
    keys[name] = { lhs = lhs, display = vim.fn.keytrans(lhs) }
  end
  return keys
end

local function prepare_tour_entry(entry, side)
  if type(entry) ~= 'table' then
    error('Tour ' .. side .. ' entry must be a table.')
  end
  local first, last = validate_showme(entry.filename, entry.range, entry.message, side)
  local filename = vim.fn.fnamemodify(entry.filename, ':p')
  local buffer = showme_buffer(filename)
  if last > vim.api.nvim_buf_line_count(buffer) then
    error 'Tour range extends beyond the end of the file.'
  end
  return {
    filename = filename,
    buffer = buffer,
    first = first,
    last = last,
    message = entry.message,
  }
end

local function refresh_tour_entry(entry)
  if vim.fn.filereadable(entry.filename) ~= 1 then
    error 'Tour filename must name a readable file.'
  end
  local buffer = showme_buffer(entry.filename)
  if entry.last > vim.api.nvim_buf_line_count(buffer) then
    error 'Tour range extends beyond the end of the file.'
  end
  entry.buffer = buffer
end

local function prepare_tour(scenes, options)
  require_showme_namespace_support()
  if type(scenes) ~= 'table' or #scenes == 0 then
    error 'Tour requires a non-empty list of scenes.'
  end
  local prepared = {}
  local keys = validate_tour_options(options)
  for index = 1, #scenes do
    local scene = scenes[index]
    if type(scene) ~= 'table' or (scene.left == nil and scene.right == nil) then
      error 'Each Tour scene requires a left and/or right entry.'
    end
    prepared[index] = {}
    if scene.left ~= nil then
      prepared[index].left = prepare_tour_entry(scene.left, 'left')
    end
    if scene.right ~= nil then
      prepared[index].right = prepare_tour_entry(scene.right, 'right')
    end
  end
  return { scenes = prepared, keys = keys }
end

local function restore_tour_mapping(mapping)
  if not vim.api.nvim_buf_is_valid(mapping.buffer) then
    return
  end
  pcall(vim.api.nvim_buf_del_keymap, mapping.buffer, 'n', mapping.key)
  if mapping.previous then
    pcall(vim.api.nvim_buf_call, mapping.buffer, function()
      vim.fn.mapset('n', false, mapping.previous)
    end)
  end
end

restore_presentation_mappings = function(state)
  for index = #state.mappings, 1, -1 do
    restore_tour_mapping(state.mappings[index])
  end
  state.mappings = {}
  state.mappings_installed = false
end

local function local_normal_map(buffer, key)
  return vim.api.nvim_buf_call(buffer, function()
    local map = vim.fn.maparg(key, 'n', false, true)
    return map.buffer == 1 and map or nil
  end)
end

configure_presentation_mappings = function()
  local state = presentation
  if
    not state
    or state.mappings_installed
    or vim.api.nvim_get_current_tabpage() ~= state.tabpage
  then
    return
  end
  local callbacks = {
    next = function()
      M.TourNext()
    end,
    prev = function()
      M.TourPrev()
    end,
    stop = function()
      M.TourStop()
    end,
    annotate = function()
      M.AnnotateShowMe()
    end,
  }
  local mapped = {}
  local names = state.tour and { 'next', 'prev', 'stop', 'annotate' }
    or { 'stop', 'annotate' }
  for _, window in ipairs(presentation_windows(state)) do
    local buffer = vim.api.nvim_win_get_buf(window)
    for _, name in ipairs(names) do
      local key = state.keys[name]
      local id = buffer .. '\0' .. key.lhs
      if not mapped[id] then
        local previous = local_normal_map(buffer, key.lhs)
        vim.keymap.set('n', key.lhs, callbacks[name], {
          buffer = buffer,
          noremap = true,
          silent = true,
        })
        table.insert(state.mappings, {
          buffer = buffer,
          key = key.lhs,
          previous = previous,
        })
        mapped[id] = true
      end
    end
  end
  state.mappings_installed = true
end

local function assert_tour_context(tour)
  if not presentation or presentation.tour ~= tour then
    error 'Tour presentation is no longer available.'
  end
  local windows = presentation_windows(presentation)
  if windows[1] ~= tour.windows[1] or windows[2] ~= tour.windows[2] then
    error 'Tour navigation requires its original side-by-side windows.'
  end
end

local function tour_footer(tour, index)
  local next_label = index == #tour.scenes and 'finish' or 'next'
  return string.format(
    '\n\nStep %d/%d  %s previous  %s %s  %s annotate  %s quit',
    index,
    #tour.scenes,
    tour.keys.prev.display,
    tour.keys.next.display,
    next_label,
    tour.keys.annotate.display,
    tour.keys.stop.display
  )
end

local function preflight_tour_scene(tour, index)
  local scene = tour.scenes[index]
  for _, side in ipairs { 'left', 'right' } do
    if scene[side] then
      refresh_tour_entry(scene[side])
    end
  end
end

local function render_tour_scene(tour, index)
  assert_tour_context(tour)
  restore_presentation_mappings(presentation)
  local scene = tour.scenes[index]
  for _, side in ipairs { 'left', 'right' } do
    local entry = scene[side]
    if entry then
      display_showme_entry({
        buffer = entry.buffer,
        first = entry.first,
        last = entry.last,
        message = entry.message,
        footer = tour_footer(tour, index),
        report = tour.report,
        step = index,
      }, side, tour.windows)
    else
      clear_showme_annotation(side)
    end
  end
end

stop_tour = function(ended_by)
  local tour = active_tour
  if not tour then
    return
  end
  finalize_active_report(ended_by or 'stopped', tour.report)
  active_tour = nil
  if presentation then
    presentation.tour = nil
    if presentation.report == tour.report then
      presentation.report = nil
    end
    restore_presentation_mappings(presentation)
  end
  clear_showme_annotation 'left'
  clear_showme_annotation 'right'
  if presentation then
    configure_presentation_mappings()
  end
end

local function protect_native_tab_leave_buffers(state)
  state.pending_bufhidden = state.pending_bufhidden or {}
  for _, window in ipairs(vim.api.nvim_tabpage_list_wins(state.tabpage)) do
    local buffer = vim.api.nvim_win_get_buf(window)
    local bufhidden = vim.bo[buffer].bufhidden
    if
      state.presented_buffers[buffer]
      and state.pending_bufhidden[buffer] == nil
      and (bufhidden == 'wipe' or bufhidden == 'delete' or bufhidden == 'unload')
    then
      state.pending_bufhidden[buffer] = bufhidden
      vim.bo[buffer].bufhidden = 'hide'
    end
  end
end

local function restore_native_tab_leave_buffers(state)
  for buffer, bufhidden in pairs(state.pending_bufhidden or {}) do
    if vim.api.nvim_buf_is_valid(buffer) and vim.bo[buffer].bufhidden == 'hide' then
      vim.bo[buffer].bufhidden = bufhidden
    end
  end
  state.pending_bufhidden = {}
end

local function close_background_timer(timer)
  if not timer:is_closing() then
    timer:stop()
    timer:close()
  end
end

local function stop_background_guard(state)
  state.background_generation = (state.background_generation or 0) + 1
  local timer = state.background_timer
  state.background_timer = nil
  if timer then
    close_background_timer(timer)
  end
end

cleanup_closed_presentation = function(state)
  if presentation ~= state then
    return
  end
  finalize_active_report(state.closing_ended_by or 'closed', state.report)
  stop_background_guard(state)
  restore_native_tab_leave_buffers(state)
  restore_presentation_mappings(state)
  active_tour = nil
  clear_showme_annotation 'left'
  clear_showme_annotation 'right'
  presentation = nil
end

local function start_background_guard(state)
  stop_background_guard(state)
  local timer = (vim.uv or vim.loop).new_timer()
  local generation = state.background_generation
  state.background_timer = timer
  timer:start(
    250,
    250,
    vim.schedule_wrap(function()
      if state.background_generation ~= generation or state.background_timer ~= timer then
        close_background_timer(timer)
        return
      end
      if presentation ~= state then
        close_background_timer(timer)
        return
      end
      if not vim.api.nvim_tabpage_is_valid(state.tabpage) then
        cleanup_closed_presentation(state)
      end
    end)
  )
end

local presentation_augroup
ensure_presentation_lifecycle = function()
  if presentation_augroup then
    return
  end
  presentation_augroup =
    vim.api.nvim_create_augroup('misc-showme-presentation', { clear = true })
  vim.api.nvim_create_autocmd('TabLeave', {
    group = presentation_augroup,
    callback = function()
      if presentation and vim.api.nvim_get_current_tabpage() == presentation.tabpage then
        local state = presentation
        protect_native_tab_leave_buffers(state)
        restore_presentation_mappings(state)
        start_background_guard(state)
      end
    end,
  })
  vim.api.nvim_create_autocmd('TabEnter', {
    group = presentation_augroup,
    callback = function()
      if presentation and vim.api.nvim_get_current_tabpage() == presentation.tabpage then
        stop_background_guard(presentation)
        restore_native_tab_leave_buffers(presentation)
        configure_presentation_mappings()
      end
    end,
  })
  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = presentation_augroup,
    callback = function()
      if presentation then
        stop_background_guard(presentation)
      end
    end,
  })
  vim.api.nvim_create_autocmd('TabClosed', {
    group = presentation_augroup,
    callback = function()
      if presentation and not vim.api.nvim_tabpage_is_valid(presentation.tabpage) then
        cleanup_closed_presentation(presentation)
      end
    end,
  })
end

local function protect_presented_buffers(state)
  local protected = {}
  for _, window in ipairs(vim.api.nvim_tabpage_list_wins(state.tabpage)) do
    local buffer = vim.api.nvim_win_get_buf(window)
    if vim.api.nvim_buf_is_valid(buffer) and protected[buffer] == nil then
      protected[buffer] = vim.bo[buffer].bufhidden
      vim.bo[buffer].bufhidden = 'hide'
    end
  end
  return protected
end

local function restore_protected_buffers(protected)
  for buffer, bufhidden in pairs(protected) do
    if vim.api.nvim_buf_is_valid(buffer) then
      vim.bo[buffer].bufhidden = bufhidden
    end
  end
end

close_presentation = function(ended_by)
  local state = presentation
  if not state then
    return
  end
  if not vim.api.nvim_tabpage_is_valid(state.tabpage) then
    state.closing_ended_by = ended_by or 'closed'
    cleanup_closed_presentation(state)
    return
  end
  local caller_tabpage = vim.api.nvim_get_current_tabpage()
  local caller_window = vim.api.nvim_get_current_win()
  local inside = caller_tabpage == state.tabpage
  if comment_editor and comment_editor.report == state.report then
    close_comment_editor(comment_editor)
  end
  stop_background_guard(state)
  restore_native_tab_leave_buffers(state)
  restore_presentation_mappings(state)
  local protected = protect_presented_buffers(state)
  if #vim.api.nvim_list_tabpages() == 1 then
    vim.cmd 'tabnew'
  end
  vim.api.nvim_set_current_tabpage(state.tabpage)
  state.closing_ended_by = ended_by or 'quit'
  local closed, close_error = pcall(vim.cmd, 'tabclose')
  restore_protected_buffers(protected)
  if not closed and vim.api.nvim_tabpage_is_valid(state.tabpage) then
    state.closing_ended_by = nil
    configure_presentation_mappings()
    error(close_error)
  end
  if presentation == state then
    cleanup_closed_presentation(state)
  end
  if inside and vim.api.nvim_tabpage_is_valid(state.origin_tabpage) then
    if vim.api.nvim_win_is_valid(state.origin_window) then
      vim.api.nvim_set_current_win(state.origin_window)
    else
      vim.api.nvim_set_current_tabpage(state.origin_tabpage)
    end
  elseif not inside and vim.api.nvim_tabpage_is_valid(caller_tabpage) then
    if vim.api.nvim_win_is_valid(caller_window) then
      vim.api.nvim_set_current_win(caller_window)
    else
      vim.api.nvim_set_current_tabpage(caller_tabpage)
    end
  end
end

M.Tour = function(scenes, options)
  local tour = prepare_tour(scenes, options)
  tour.index = 1
  preflight_tour_scene(tour, tour.index)
  local windows = ensure_presentation()
  if active_tour then
    stop_tour 'replaced'
  elseif active_report then
    finalize_active_report('replaced', active_report)
  end
  tour.report = new_feedback_report 'tour'
  restore_presentation_mappings(presentation)
  tour.windows = windows
  presentation.keys = tour.keys
  presentation.tour = tour
  presentation.report = tour.report
  active_tour = tour
  ensure_presentation_lifecycle()
  local ok, render_error = pcall(render_tour_scene, tour, tour.index)
  if not ok then
    stop_tour 'render_failed'
    error(render_error)
  end
  configure_presentation_mappings()
  return tour.report.id
end

M.TourNext = function()
  local tour = active_tour
  if not tour then
    return
  end
  if tour.index == #tour.scenes then
    close_presentation 'finished'
    return
  end
  local next_index = tour.index + 1
  assert_tour_context(tour)
  preflight_tour_scene(tour, next_index)
  vim.api.nvim_set_current_tabpage(presentation.tabpage)
  render_tour_scene(tour, next_index)
  tour.index = next_index
  configure_presentation_mappings()
end

M.TourPrev = function()
  local tour = active_tour
  if not tour then
    return
  end
  assert_tour_context(tour)
  if tour.index == 1 then
    vim.api.nvim_set_current_tabpage(presentation.tabpage)
    return
  end
  local previous_index = tour.index - 1
  preflight_tour_scene(tour, previous_index)
  vim.api.nvim_set_current_tabpage(presentation.tabpage)
  render_tour_scene(tour, previous_index)
  tour.index = previous_index
  configure_presentation_mappings()
end

M.TourStop = function()
  close_presentation 'stopped'
end

return M
