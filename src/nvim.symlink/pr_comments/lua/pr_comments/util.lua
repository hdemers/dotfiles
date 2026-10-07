-- vim: ts=2 sts=2 sw=2 et
local M = {}

function M.notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = 'pr-comments' })
end

--- Run a command asynchronously; callback(ok, stdout, stderr) on the main loop.
function M.run(cmd, opts, cb)
  vim.system(
    cmd,
    vim.tbl_extend('force', { text = true }, opts or {}),
    vim.schedule_wrap(function(obj)
      cb(obj.code == 0, obj.stdout or '', obj.stderr or '')
    end)
  )
end

--- Parse `https://host/owner/repo/pull/N` into `owner/repo`.
function M.repo_from_url(url)
  return url:match '^https?://[^/]+/([^/]+/[^/]+)/pull/%d+'
end

--- Repo root and repo-relative path of a buffer's file.
---@return { root: string, path: string }|nil ctx
---@return string|nil err
function M.buf_context(buf)
  local name = vim.api.nvim_buf_get_name(buf)
  if name == '' then
    return nil, 'Current buffer is not a file on disk'
  end
  -- Resolve symlinked *directories* (e.g. ~/src/nvim -> dotfiles) but not the
  -- file itself: git tracks a symlink under its own path.
  local dir = vim.uv.fs_realpath(vim.fs.dirname(name))
  local abs = dir and vim.fs.joinpath(dir, vim.fs.basename(name))
  if not abs or not vim.uv.fs_lstat(abs) then
    return nil, 'Current buffer is not a file on disk'
  end
  local root = vim.fs.root(dir, { '.jj', '.git' })
  if not root then
    return nil, 'Not inside a jj/git repository'
  end
  root = vim.uv.fs_realpath(root)
  local path = vim.fs.relpath(root, abs)
  if not path then
    return nil, 'Cannot compute repo-relative path'
  end
  return { root = root, path = path }
end

local repo_cache = {} -- root -> 'owner/repo' | false (unknown)
local repo_waiters = {} -- root -> callbacks while a lookup is in flight

--- `owner/repo` of a repo root as seen by gh (nil when it can't be determined).
function M.repo_of(root, cb)
  if repo_cache[root] ~= nil then
    return cb(repo_cache[root] or nil)
  end
  if repo_waiters[root] then
    return table.insert(repo_waiters[root], cb)
  end
  repo_waiters[root] = { cb }
  M.run(
    { 'gh', 'repo', 'view', '--json', 'nameWithOwner', '-q', '.nameWithOwner' },
    { cwd = root },
    function(ok, out)
      local repo = ok and vim.trim(out) ~= '' and vim.trim(out) or false
      repo_cache[root] = repo
      local waiters = repo_waiters[root]
      repo_waiters[root] = nil
      for _, w in ipairs(waiters) do
        w(repo or nil)
      end
    end
  )
end

local me_cache -- login | false

--- Login of the authenticated gh user (nil if unknown).
function M.whoami(cb)
  if me_cache ~= nil then
    return cb(me_cache or nil)
  end
  M.run({ 'gh', 'api', 'user', '-q', '.login' }, {}, function(ok, out)
    me_cache = ok and vim.trim(out) ~= '' and vim.trim(out) or false
    cb(me_cache or nil)
  end)
end

return M
