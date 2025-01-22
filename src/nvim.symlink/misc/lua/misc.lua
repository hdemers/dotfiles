-- vim: ts=2 sts=2 sw=2 et
local M = {}

M.setup = function()
  vim.api.nvim_create_user_command('StartPyscriptKernel', function()
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

    local job =
      vim.system(cmd, { text = true, stdout = stdout, stderr = stdout }, on_exit)

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
  end, {})
end

M.check_for_ipython = function()
  local distrobox_name = os.getenv 'DISTROBOX_NAME' or 'grubhub-dev'
  -- Check if ipython is available in the distrobox
  _G.ipython_available = false
  vim.notify(
    'Checking for ipython availability in ' .. distrobox_name,
    vim.log.levels.INFO
  )
  local handle =
    io.popen('distrobox enter ' .. distrobox_name .. ' -- which ipython 2>/dev/null')
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
      -- Create a function that returns a promise-like object
      local function wait_for_command(cmd)
        local done = false

        local term = Terminal:new {
          direction = 'float',
          cmd = cmd,
          hidden = false,
          close_on_exit = false,
          float_opts = { width = 100, height = 40 },
          on_exit = function(t, _, code, _)
            if code ~= 0 then
              vim.notify('Failed to install ipykernel', vim.log.levels.ERROR)
              vim.defer_fn(function()
                t:close()
              end, 3000)
              _G.ipython_available = false
            end
            done = true
            _G.ipython_available = true
          end,
        }

        term:open()

        -- Wait for the terminal to finish
        vim.wait(30000, function()
          return done
        end, 100)

        -- Give a small delay for cleanup
        vim.defer_fn(function()
          term:close()
        end, 1000)
      end

      local cmd = 'distrobox enter ' .. distrobox_name .. ' -- uv pip install ipykernel'

      -- Use the waiting terminal
      wait_for_command(cmd)
    end
  else
    _G.ipython_available = true
  end
end

M.start_ipython_kernel = function()
  local toggleterm = require 'toggleterm'
  local box_name = os.getenv 'DISTROBOX_NAME' or 'grubhub-dev'
  local terminal_id = 42

  if not _G.ipython_term then
    vim.notify('Entering distrobbox.', vim.log.levels.INFO)
    toggleterm.toggle(terminal_id)
    vim.wait(2000)
    toggleterm.exec('distrobox enter ' .. box_name, terminal_id)
    _G.ipython_term = true
  end

  if not _G.ipython_available then
    M.check_for_ipython()
    vim.wait(1000, function()
      return _G.ipython_available
    end, 100)
    if _G.ipython_available then
      vim.wait(2000)
      toggleterm.exec('ipython --no-autoindent', terminal_id)
      _G.ipython_started = true
    else
      vim.notify('ipython is not available', vim.log.levels.ERROR)
      _G.ipython_started = false
      return
    end
  end
end

vim.api.nvim_create_user_command('StartIPython', M.start_ipython_kernel, {})

return M
