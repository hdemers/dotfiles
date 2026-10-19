local uv = vim.uv
local published_path
local published_address

local function warn(message)
  pcall(vim.notify, message, vim.log.levels.WARN)
end

local function close_file(fd)
  local called, result, close_error = pcall(uv.fs_close, fd)
  if called and result then
    return true
  end
  return false, close_error or result
end

local function remove_temporary(path)
  local removed, remove_error = uv.fs_unlink(path)
  if not removed then
    warn(string.format('Could not remove temporary Neovim server file: %s', remove_error))
  end
end

local function create_temporary(directory)
  local fd, path_or_error = uv.fs_mkstemp(directory .. '/,.nvim.server.XXXXXX')
  if not fd then
    warn(string.format('Could not create Neovim server file: %s', path_or_error))
    return nil
  end
  return fd, path_or_error
end

local function read_regular_file(path)
  local stat, stat_error = uv.fs_lstat(path)
  if not stat then
    if stat_error and not stat_error:match 'ENOENT' then
      return nil, stat_error
    end
    return nil
  end
  if stat.type ~= 'file' then
    return nil
  end

  local fd, open_error = uv.fs_open(path, 'r', 384)
  if not fd then
    return nil, open_error
  end

  local content, read_error = uv.fs_read(fd, stat.size, 0)
  local closed, close_error = close_file(fd)
  if not content then
    return nil, read_error
  end
  if not closed then
    return nil, close_error
  end
  return content
end

local function publish(path, address)
  local directory = vim.fn.fnamemodify(path, ':h')
  local fd, temporary = create_temporary(directory)
  if not fd then
    return false
  end

  local content = address .. '\n'
  local written, write_error = uv.fs_write(fd, content, 0)
  local closed, close_error = close_file(fd)
  if written ~= #content or not closed then
    remove_temporary(temporary)
    warn(
      string.format(
        'Could not write Neovim server address: %s',
        write_error or close_error
      )
    )
    return false
  end

  local renamed, rename_error = uv.fs_rename(temporary, path)
  if renamed then
    return true
  end
  remove_temporary(temporary)
  warn(string.format('Could not publish Neovim server address: %s', rename_error))
  return false
end

local function restore_foreign_claim(claim, path)
  local stat, stat_error = uv.fs_lstat(claim)
  if not stat or (stat.type ~= 'file' and stat.type ~= 'link') then
    warn(
      string.format(
        'Could not safely restore foreign Neovim server record at %s: %s',
        claim,
        stat_error or 'record is not a regular file or symlink'
      )
    )
    return
  end

  local linked, link_error = uv.fs_link(claim, path)
  if linked then
    remove_temporary(claim)
    return
  end

  if uv.fs_lstat(path) then
    remove_temporary(claim)
    return
  end

  warn(
    string.format(
      'Could not restore foreign Neovim server record at %s: %s',
      claim,
      link_error
    )
  )
end

local function clean_up()
  if not published_path or not published_address then
    return
  end

  local expected = published_address .. '\n'
  local content, read_error = read_regular_file(published_path)
  if content ~= expected then
    if read_error then
      warn(
        string.format('Could not read Neovim server address for cleanup: %s', read_error)
      )
    end
    return
  end

  -- Claim atomically, then restore foreign claims without replacing a newer publication.
  local directory = vim.fn.fnamemodify(published_path, ':h')
  local fd, claim = create_temporary(directory)
  if not fd then
    return
  end
  local closed, close_error = close_file(fd)
  if not closed then
    remove_temporary(claim)
    warn(string.format('Could not close Neovim server claim file: %s', close_error))
    return
  end

  local claimed, claim_error = uv.fs_rename(published_path, claim)
  if not claimed then
    remove_temporary(claim)
    if claim_error and not claim_error:match 'ENOENT' then
      warn(
        string.format(
          'Could not claim Neovim server address for cleanup: %s',
          claim_error
        )
      )
    end
    return
  end

  content, read_error = read_regular_file(claim)
  if content == expected then
    remove_temporary(claim)
  else
    if read_error then
      warn(string.format('Could not read claimed Neovim server address: %s', read_error))
    end
    restore_foreign_claim(claim, published_path)
  end
end

vim.api.nvim_create_autocmd('VimEnter', {
  group = vim.api.nvim_create_augroup('nvim-server-file', { clear = true }),
  callback = function()
    local address = vim.v.servername
    if #vim.api.nvim_list_uis() == 0 or address == '' then
      return
    end

    local directory = vim.fn.getcwd()
    local path = directory .. '/.nvim.server'
    if publish(path, address) then
      published_path = path
      published_address = address
    end
  end,
})

vim.api.nvim_create_autocmd('VimLeavePre', {
  group = 'nvim-server-file',
  callback = clean_up,
})
