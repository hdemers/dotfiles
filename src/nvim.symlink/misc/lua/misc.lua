-- vim: ts=2 sts=2 sw=2 et
local M = {}

M.setup = function()
  vim.api.nvim_create_user_command('StartPyscriptKernel', M.start_pyscript_kernel, {})
  vim.api.nvim_create_user_command('StartIPython', M.start_ipython, {})
end

M.spawn_ipython_term = function()
  local box_name = os.getenv 'DBX_CONTAINER_NAME' or 'grubhub-dev'
  local Terminal = require('toggleterm.terminal').Terminal
  local ipython_cmd = 'distrobox enter ' .. box_name .. ' -- ipython --no-autoindent'

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
  -- Check if ipython is available in the distrobox
  vim.notify('Checking for ipython availability in ' .. box_name, vim.log.levels.INFO)
  local handle =
    io.popen('distrobox enter ' .. box_name .. ' -- which ipython 2>/dev/null')
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
      local cmd = 'distrobox enter ' .. box_name .. ' -- uv pip install ipykernel'
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

return M
