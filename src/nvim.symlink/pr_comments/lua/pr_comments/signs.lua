-- vim: ts=2 sts=2 sw=2 et
--- Fetch the comments of the current PR and show them as signs.
local util = require 'pr_comments.util'

local M = {}

M.config = { icon = vim.fn.nr2char(0xf075), max_body = 60 } -- nerd-font comment glyph

local ns = vim.api.nvim_create_namespace 'pr_comments_signs'
local cache = {} -- "owner/repo#N" -> { threads_by_path = {...}, unplaced = n }
local waiters = {} -- key -> callbacks while a fetch is in flight

local function key(pr)
  return string.format('%s#%d', pr.repo, pr.number)
end

local function decode(out)
  local ok, data = pcall(vim.json.decode, out)
  return ok and type(data) == 'table' and data or nil
end

--- Group review comments into threads located by their root comment.
local function build(comments)
  local by_id = {}
  for _, c in ipairs(comments) do
    if c.type == 'review_comment' then
      by_id[c.id] = c
    end
  end

  local threads = {}
  for _, c in pairs(by_id) do
    local root, guard = c, 0
    while root.in_reply_to_id and by_id[root.in_reply_to_id] and guard < 100 do
      root = by_id[root.in_reply_to_id]
      guard = guard + 1
    end
    local t = threads[root.id]
    if not t then
      t = { root = root, comments = {}, pending = false }
      threads[root.id] = t
    end
    table.insert(t.comments, c)
    t.pending = t.pending or c.pending == true
  end

  local by_path, unplaced = {}, 0
  for _, t in pairs(threads) do
    table.sort(t.comments, function(a, b)
      return (a.created_at or '') < (b.created_at or '')
    end)
    local r = t.root
    t.resolved = r.resolved == true
    t.outdated = r.outdated == true
    t.file_level = r.subject_type == 'file'
    if t.file_level then
      t.first, t.last = 1, 1 -- no line: pin to the top of the file
    elseif type(r.line) == 'number' then
      t.last = r.line
      t.first = type(r.start_line) == 'number' and r.start_line or r.line
    elseif type(r.original_line) == 'number' then
      -- Outdated: show where the comment was written, as a best effort.
      t.last = r.original_line
      t.first = type(r.original_start_line) == 'number' and r.original_start_line or r.original_line
    end
    if t.first and r.path then
      by_path[r.path] = by_path[r.path] or {}
      table.insert(by_path[r.path], t)
    else
      unplaced = unplaced + 1
    end
  end
  return { threads_by_path = by_path, unplaced = unplaced }
end

--- Fetch submitted + pending comments of a PR and cache them.
---@param pr { repo: string, number: integer }
---@param cb fun()|nil
function M.fetch(pr, cb)
  local k = key(pr)
  if waiters[k] then
    if cb then
      table.insert(waiters[k], cb)
    end
    return
  end
  waiters[k] = { cb }

  local results, left = {}, 2
  local function finish()
    left = left - 1
    if left > 0 then
      return
    end
    local all = {}
    local seen = {}
    for _, c in ipairs(results.pending or {}) do
      c.pending = true
      seen[c.id] = true
      table.insert(all, c)
    end
    for _, c in ipairs(results.list or {}) do
      if not seen[c.id] then
        table.insert(all, c)
      end
    end
    if results.list then -- keep the old cache if the main fetch failed
      cache[k] = build(all)
    end
    local cbs = waiters[k]
    waiters[k] = nil
    for _, f in ipairs(cbs) do
      f()
    end
  end

  local base = { 'pr-comments', 'list', pr.repo, tostring(pr.number) }
  util.run(base, {}, function(ok, out, err)
    if ok then
      results.list = decode(out)
    else
      util.notify('pr-comments list failed: ' .. vim.trim(err), vim.log.levels.ERROR)
    end
    finish()
  end)
  util.run(vim.list_extend(vim.deepcopy(base), { '--pending' }), {}, function(ok, out)
    results.pending = ok and decode(out) or {}
    finish()
  end)
end

--- Call `cb` once comments of `pr` are cached (fetching if needed).
function M.ensure(pr, cb)
  if cache[key(pr)] then
    return cb()
  end
  M.fetch(pr, cb)
end

--- Threads of `pr` covering line `lnum` (1-based) of repo-relative `path`.
function M.threads_at(pr, path, lnum)
  local data = cache[key(pr)]
  local res = {}
  for _, t in ipairs(data and data.threads_by_path[path] or {}) do
    if lnum >= t.first and lnum <= t.last then
      table.insert(res, t)
    end
  end
  return res
end

function M.render(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  local pr = vim.g.pr_comments_current
  local data = pr and cache[key(pr)]
  if not data or vim.bo[buf].buftype ~= '' then
    return
  end
  local ctx = util.buf_context(buf)
  local threads = ctx and data.threads_by_path[ctx.path]
  if not threads then
    return
  end

  -- Only decorate buffers belonging to the PR's repo (unknown repo: assume yes).
  util.repo_of(ctx.root, function(repo)
    if repo and repo ~= pr.repo then
      return
    end
    local cur = vim.g.pr_comments_current
    if not vim.api.nvim_buf_is_valid(buf) or not cur or key(cur) ~= key(pr) then
      return
    end
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    local nlines = vim.api.nvim_buf_line_count(buf)
    local per_line = {}
    for _, t in ipairs(threads) do
      for l = t.first, math.min(t.last, nlines) do
        per_line[l] = per_line[l] or {}
        table.insert(per_line[l], t)
      end
    end
    for l, ts in pairs(per_line) do
      local rank, hl = 0, 'PRCommentResolved'
      local order = { PRCommentResolved = 1, PRCommentOutdated = 2, PRCommentOpen = 3, PRCommentPending = 4 }
      for _, t in ipairs(ts) do
        local g = t.pending and 'PRCommentPending'
          or (t.outdated and 'PRCommentOutdated')
          or (t.resolved and 'PRCommentResolved')
          or 'PRCommentOpen'
        if order[g] > rank then
          rank, hl = order[g], g
        end
      end
      pcall(vim.api.nvim_buf_set_extmark, buf, ns, l - 1, 0, {
        sign_text = #ts > 1 and tostring(math.min(#ts, 9)) or M.config.icon,
        sign_hl_group = hl,
      })
    end
  end)
end

function M.render_all()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then
      M.render(buf)
    end
  end
end

--- Refetch the current PR's comments and redraw all signs.
function M.refresh(cb)
  local pr = vim.g.pr_comments_current
  M.render_all() -- clears stale signs right away when the PR changed
  if not pr then
    return cb and cb()
  end
  M.fetch(pr, function()
    M.render_all()
    local data = cache[key(pr)]
    if data and data.unplaced > 0 then
      vim.notify(
        string.format('%d comment thread(s) could not be placed in a file', data.unplaced),
        vim.log.levels.DEBUG,
        { title = 'pr-comments' }
      )
    end
    if cb then
      cb()
    end
  end)
end

function M.setup(opts)
  M.config = vim.tbl_extend('force', M.config, opts or {})
  vim.api.nvim_set_hl(0, 'PRCommentOpen', { link = 'DiagnosticInfo', default = true })
  vim.api.nvim_set_hl(0, 'PRCommentPending', { link = 'DiagnosticWarn', default = true })
  vim.api.nvim_set_hl(0, 'PRCommentOutdated', { link = 'DiagnosticHint', default = true })
  vim.api.nvim_set_hl(0, 'PRCommentResolved', { link = 'Comment', default = true })

  local group = vim.api.nvim_create_augroup('PRCommentSigns', { clear = true })
  vim.api.nvim_create_autocmd('BufEnter', {
    group = group,
    callback = function(args)
      local pr = vim.g.pr_comments_current
      if not pr then
        return
      end
      if cache[key(pr)] then
        M.render(args.buf)
      else
        M.refresh()
      end
    end,
  })
  vim.api.nvim_create_autocmd('User', {
    group = group,
    pattern = 'PRCommentsPRChanged',
    callback = function()
      M.refresh()
    end,
  })
end

return M
