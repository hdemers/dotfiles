-- vim: ts=2 sts=2 sw=2 et
local M = {}

M.setup = function()
  vim.api.nvim_create_user_command('StartPyscriptKernel', M.start_pyscript_kernel, {})
  vim.api.nvim_create_user_command('StartIPython', M.start_ipython, {})
end

M.spawn_ipython_term = function()
  local box_name = os.getenv 'DBX_CONTAINER_NAME'
  local Terminal = require('toggleterm.terminal').Terminal
  local ipython_cmd = 'ipython --no-autoindent'
  if not os.getenv 'CONTAINER_ID' then
    ipython_cmd = 'distrobox enter ' .. box_name .. ' -- ' .. ipython_cmd
  end

  M.ipython_term = nil

  if not box_name then
    vim.notify('DBX_CONTAINER_NAME is not set', vim.log.levels.ERROR)
    return
  end

  M.ipython_term = Terminal:new {
    direction = 'vertical',
    cmd = ipython_cmd,
    hidden = false,
    close_on_exit = true,
    on_exit = function(_, _, _, _)
      M.ipython_term = nil
    end,
  }
  M.ipython_term:open()
  vim.wait(3000)
end

M.check_for_ipython = function()
  local box_name = os.getenv 'DBX_CONTAINER_NAME'
  M.ipython_available = false

  if not box_name then
    vim.notify('DBX_CONTAINER_NAME is not set', vim.log.levels.ERROR)
    return
  end

  local cmd = 'which ipython 2>/dev/null'
  local container_cmd = ''
  if not os.getenv 'CONTAINER_ID' then
    container_cmd = 'distrobox enter ' .. box_name .. ' -- '
  end
  -- Check if ipython is available in the distrobox
  vim.notify('Checking for ipython availability in ' .. box_name, vim.log.levels.INFO)
  local handle = io.popen(container_cmd .. cmd)
  if not handle then
    vim.notify('Failed to check for ipython.', vim.log.levels.ERROR)
    return nil
  end

  local result = handle:read '*a'
  handle:close()

  if result == '' then
    -- Prompt user to install ipykernel
    local input =
      vim.fn.input('Confirm', 'ipython not found. Install ipykernel? [y/N]: '):sub(-1)

    if input and input:lower() == 'y' then
      local Terminal = require('toggleterm.terminal').Terminal
      local cmd = container_cmd .. 'uv pip install ipykernel'
      Terminal
        :new({
          direction = 'float',
          cmd = cmd,
          hidden = false,
          close_on_exit = false,
          float_opts = { width = 100, height = 40 },
          on_exit = function(t, _, code, _)
            if code ~= 0 then
              vim.notify('Failed to install ipykernel', vim.log.levels.ERROR)
              vim.wait(3000)
              M.ipython_available = false
            else
              vim.notify('Successfully installed ipykernel', vim.log.levels.INFO)
              M.ipython_available = true
            end
            t:close()
          end,
        })
        :open()
    end
  else
    M.ipython_available = true
  end
end

M.start_ipython = function()
  if not M.ipython_term then
    if not M.ipython_available then
      M.check_for_ipython()
      vim.wait(7000, function()
        return M.ipython_available
      end, 100)
    end

    -- vim.wait(1000, function()
    --   return M.ipython_available
    -- end, 100)
    if M.ipython_available then
      M.spawn_ipython_term()
    else
      vim.notify('ipython is not available', vim.log.levels.ERROR)
      return
    end
  end
end

M.start_pyscript_kernel = function()
  local connection_file = nil

  local virtual_env = os.getenv 'VIRTUAL_ENV'
  if virtual_env == nil or not string.match(virtual_env, '.*pyscript$') then
    vim.notify(
      'Virtualenv is not `pyscript` (is' .. virtual_env .. '). Aborting.',
      vim.log.levels.ERROR
    )
    return
  end

  local on_exit = vim.schedule_wrap(function(obj)
    if obj.code ~= 0 then
      vim.notify('jupyter console failed', vim.log.levels.ERROR)
    end
  end)

  local cmd = {
    'jupyter',
    'kernel',
    '--kernel',
    'pyscript',
  }
  -- vim.notify(
  --   'Starting pyscript kernel, cmd is ' .. table.concat(cmd, ' '),
  --   vim.log.levels.INFO
  -- )

  local init = vim.schedule_wrap(function(connection)
    vim.notify('Attaching to kernel using ' .. connection, vim.log.levels.INFO)
    vim.cmd('JupyterAttach ' .. connection)
    vim.cmd('MoltenInit ' .. connection)
  end)

  local stdout = function(err, data)
    if err then
      vim.notify('Error: ' .. err, vim.log.levels.ERROR)
    end
    if data then
      local pattern = 'Connection file: (/[%w%p]+%.json)'
      connection_file = string.match(data, pattern)

      if connection_file ~= nil then
        vim.notify(
          'Kernel pyscript started with connection file ' .. connection_file,
          vim.log.levels.INFO
        )
        init(connection_file)
      end
    end
  end

  local job = vim.system(cmd, { text = true, stdout = stdout, stderr = stdout }, on_exit)

  -- Define a cleanup function to terminate the job
  local function cleanup()
    if job then
      -- Signal the process to terminate
      job:kill(15)
    end
  end

  -- Register the cleanup function on VimLeavePre event
  vim.api.nvim_create_autocmd('VimLeavePre', {
    callback = cleanup,
  })
end

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

  -- Dynamically create the highlight groups each time
  vim.cmd(
    'highlight TabLineSelSymbol guifg='
      .. tab_sel_colors.bg
      .. ' guibg='
      .. tab_fill_colors.bg
  )
  vim.cmd(
    'highlight TabLineSymbol guifg='
      .. tab_line_colors.bg
      .. ' guibg='
      .. tab_fill_colors.bg
  )

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
    -- Set highlight groups
    local is_selected = i == current_tab
    local tab_hl = is_selected and 'TabLineSel' or 'TabLine'
    local symbol_hl = is_selected and 'TabLineSelSymbol' or 'TabLineSymbol'

    -- Add left symbol with appropriate highlight
    s = s .. '%#' .. symbol_hl .. '#'
    -- s = s .. ' '
    s = s .. ' '

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
    s = s .. '%#' .. symbol_hl .. '#'
    -- s = s .. ' '
    s = s .. ' '
    -- s = s .. ' '
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
