return {
  name = 'integrate',
  builder = function()
    local ticket = nil
    local branch = vim.fn.system 'git rev-parse --abbrev-ref HEAD'

    vim.notify('Integrating branch: ' .. branch, vim.log.levels.INFO)

    -- Get the latest commit of the current branch (full message)
    local handle = io.popen 'git log -1 --format="%B"'
    if handle then
      local first_commit_message = handle:read '*a'
      handle:close()

      if first_commit_message then
        -- Remove newlines and extract Jira ticket pattern (e.g., ABC-123, PROJ-456, REX-2009)
        -- Look for pattern anywhere in the commit message
        first_commit_message = first_commit_message:gsub('\n', ' ')
        ticket = first_commit_message:match '([A-Z]+%-%d+)'
        if ticket then
          vim.notify('Will close ticket: ' .. ticket, vim.log.levels.INFO)
        end
      end
    end
    local metadata = {
      branch = branch,
      ticket = ticket,
      container_name = os.getenv 'DBX_CONTAINER_NAME',
    }

    return {
      cmd = (function()
        if os.getenv 'CONTAINER_ID' then
          return { 'jenkins', 'integrate' }
        else
          local container_name = os.getenv 'DBX_CONTAINER_NAME'
          return { 'distrobox', 'enter', container_name, '--', 'jenkins', 'integrate' }
        end
      end)(),
      components = {
        { 'custom.on_pre_start_check_pushed' },
        { 'custom.on_pre_start_check_ticket' },
        { 'on_exit_set_status' },
        { 'custom.on_complete_ntfy' },
        { 'custom.on_complete_close_ticket' },
      },
      metadata = metadata,
    }
  end,
  desc = 'Integrate branch',
}
