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

return M
