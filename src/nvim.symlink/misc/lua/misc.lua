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
  local container_name = os.getenv 'DBX_CONTAINER_NAME'
  local cmd = string.format('xdg-open %s', url)

  if container_name then
    cmd = string.format('gtk-launch %s-google-chrome.desktop "%s"', container_name, url)
  end

  vim.notify('Opening URL: ' .. url, vim.log.levels.INFO)
  vim.fn.jobstart(cmd)
  vim.notify('Opening in browser: ' .. url, vim.log.levels.INFO)
end

return M
