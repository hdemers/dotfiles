-- vim: ts=2 sts=2 sw=2 et
--- Add / edit pending PR review comments from nvim through the `pr-comments` CLI.
local util = require 'pr_comments.util'
local signs = require 'pr_comments.signs'

local notify = util.notify
local run = util.run

local M = {}

local WIDTH = 80
local HEIGHT = 12

---------------------------------------------------------------------------
-- PR selection
---------------------------------------------------------------------------

--- Currently selected PR (global so other tooling/statusline can read it).
---@return { number: integer, repo: string, title: string, headRefName: string }|nil
function M.current()
  return vim.g.pr_comments_current
end

---@param pr table raw `gh pr list` entry
---@return boolean ok
local function set_current(pr)
  local repo = util.repo_from_url(pr.url or '')
  if not repo then
    notify('Cannot parse repo from ' .. tostring(pr.url), vim.log.levels.ERROR)
    return false
  end
  vim.g.pr_comments_current = {
    number = pr.number,
    repo = repo,
    title = pr.title,
    headRefName = pr.headRefName,
  }
  notify(string.format('Reviewing %s#%d: %s', repo, pr.number, pr.title))
  vim.api.nvim_exec_autocmds('User', { pattern = 'PRCommentsPRChanged' })
  return true
end

---@param opts { all: boolean|nil, cwd: string|nil }
---@param cb fun(prs: table[])  called only on success with a non-empty list
local function list_prs(opts, cb)
  run({
    'gh',
    'pr',
    'list',
    '--state',
    opts.all and 'all' or 'open',
    '--json',
    'number,title,author,state,headRefName,url',
  }, { cwd = opts.cwd or vim.fn.getcwd() }, function(ok, out, err)
    if not ok then
      return notify('gh pr list failed: ' .. vim.trim(err), vim.log.levels.ERROR)
    end
    local decoded, prs = pcall(vim.json.decode, out)
    if not decoded or type(prs) ~= 'table' or #prs == 0 then
      return notify('No pull requests found', vim.log.levels.WARN)
    end
    cb(prs)
  end)
end

---@param prs table[]
---@param opts { all: boolean|nil, on_select: fun(pr: table)|nil }
local function pick_pr(prs, opts)
  local ok, snacks = pcall(require, 'snacks')
  if not ok then
    return notify('snacks.nvim is required to select a PR', vim.log.levels.ERROR)
  end

  local gh_preview
  pcall(function()
    gh_preview = require('snacks.picker.source.gh').preview
  end)

  local items = {}
  for _, pr in ipairs(prs) do
    local repo = util.repo_from_url(pr.url or '')
    local uri = repo and string.format('gh://%s/pr/%d', repo, pr.number) or nil
    table.insert(items, {
      text = string.format('#%d %s [%s] @%s', pr.number, pr.title, pr.state, pr.author.login),
      pr = pr,
      type = 'pr',
      repo = repo,
      hash = '#' .. pr.number,
      uri = uri,
      file = uri,
    })
  end

  snacks.picker {
    title = opts.all and 'Select PR (all)' or 'Select PR (open)',
    items = items,
    preview = gh_preview,
    format = function(item)
      local pr = item.pr
      local current = vim.g.pr_comments_current
      local selected = current and current.number == pr.number and current.repo == item.repo
      local open = pr.state == 'OPEN'
      return {
        { selected and '* ' or '  ', 'Special' },
        { '#' .. pr.number, 'Special' },
        { ' ' },
        { open and '' or '', open and 'DiagnosticOk' or 'DiagnosticError' },
        { ' ' },
        { pr.title },
        { ' ' },
        { '@' .. pr.author.login, 'Comment' },
      }
    end,
    confirm = function(picker, item)
      picker:close()
      if item and item.pr and set_current(item.pr) and opts.on_select then
        opts.on_select(item.pr)
      end
    end,
  }
end

--- Pick a PR with snacks and store it in `vim.g.pr_comments_current`.
---@param opts { all: boolean|nil, cwd: string|nil }|nil
function M.select(opts)
  opts = opts or {}
  list_prs(opts, function(prs)
    pick_pr(prs, opts)
  end)
end

--- Run `cb` with the current PR. When none is selected: auto-pin the repo's
--- only open PR, or ask the user to choose when there are several.
---@param cwd string
---@param cb fun(pr: table)
local function with_current_pr(cwd, cb)
  local pr = M.current()
  if pr then
    return cb(pr)
  end
  list_prs({ cwd = cwd }, function(prs)
    local function selected()
      local cur = M.current()
      if cur then
        cb(cur)
      end
    end
    if #prs == 1 then
      if set_current(prs[1]) then
        selected()
      end
    else
      pick_pr(prs, { on_select = selected })
    end
  end)
end

---------------------------------------------------------------------------
-- Body input popup
---------------------------------------------------------------------------

--- Open a modal float to write the comment body.
---@param title string
---@param on_submit fun(body: string)
---@param initial string|nil pre-filled text
local function open_body_input(title, on_submit, initial)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].filetype = 'markdown'
  vim.bo[buf].bufhidden = 'wipe'
  if initial and initial ~= '' then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(initial, '\n', { plain = true }))
  end

  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    row = math.floor((vim.o.lines - HEIGHT) / 2),
    col = math.floor((vim.o.columns - WIDTH) / 2),
    width = WIDTH,
    height = HEIGHT,
    border = 'rounded',
    title = ' ' .. title .. ' │ <C-s> / <CR> (normal) submit │ q cancel ',
    title_pos = 'center',
  })
  vim.wo[win].wrap = true
  vim.wo[win].linebreak = true

  local function close()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    vim.cmd.stopinsert()
  end

  local function submit()
    local body = vim.trim(table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n'))
    if body == '' then
      notify('Empty comment, not submitted', vim.log.levels.WARN)
      return
    end
    close()
    on_submit(body)
  end

  vim.keymap.set({ 'n', 'i' }, '<C-s>', submit, { buffer = buf, desc = 'Submit comment' })
  vim.keymap.set('n', '<CR>', submit, { buffer = buf, nowait = true, desc = 'Submit comment' })
  vim.keymap.set('n', 'q', close, { buffer = buf, nowait = true, desc = 'Cancel' })
  vim.keymap.set('n', '<Esc>', close, { buffer = buf, nowait = true, desc = 'Cancel' })

  if initial and initial ~= '' then
    vim.cmd.stopinsert()
  else
    vim.cmd.startinsert()
  end
end

---------------------------------------------------------------------------
-- Add / edit
---------------------------------------------------------------------------

local function describe_target(path, opts)
  if not opts.line then
    return path
  end
  local range = (opts.start_line and opts.start_line ~= opts.line) and (opts.start_line .. '-')
    or ''
  return string.format('%s:%s%d', path, range, opts.line)
end

local function start_add(ctx, pr, opts)
  local target = describe_target(ctx.path, opts)
  open_body_input(string.format('%s#%d %s', pr.repo, pr.number, target), function(body)
    local cmd = { 'pr-comments', 'add', pr.repo, tostring(pr.number), '--path', ctx.path }
    if opts.line then
      if opts.start_line and opts.start_line ~= opts.line then
        vim.list_extend(cmd, { '--start-line', tostring(opts.start_line) })
      end
      vim.list_extend(cmd, { '--line', tostring(opts.line) })
    end
    vim.list_extend(cmd, { '--body-file', '-' })

    run(cmd, { cwd = ctx.root, stdin = body }, function(ok, _, err)
      if ok then
        notify(string.format('Added pending comment on %s#%d (%s)', pr.repo, pr.number, target))
        signs.refresh()
      else
        notify('pr-comments add failed:\n' .. vim.trim(err), vim.log.levels.ERROR)
      end
    end)
  end)
end

local function start_edit(ctx, pr, comment)
  local title = string.format('Edit %s#%d %s:%s', pr.repo, pr.number, ctx.path, comment.line or '')
  open_body_input(title, function(body)
    run({
      'pr-comments',
      'edit',
      pr.repo,
      tostring(pr.number),
      tostring(comment.id),
      '--type',
      'review_comment',
      '--body-file',
      '-',
    }, { cwd = ctx.root, stdin = body }, function(ok, _, err)
      if ok then
        notify(string.format('Edited comment %d on %s#%d', comment.id, pr.repo, pr.number))
        signs.refresh()
      else
        notify('pr-comments edit failed:\n' .. vim.trim(err), vim.log.levels.ERROR)
      end
    end)
  end, comment.body)
end

--- Comments of mine on `lnum`, across all threads covering it.
local function my_comments_at(pr, path, lnum, me)
  local res = {}
  for _, t in ipairs(signs.threads_at(pr, path, lnum)) do
    for _, c in ipairs(t.comments) do
      if me == nil or c.author == me then
        table.insert(res, c)
      end
    end
  end
  return res
end

local function summarize(c)
  local first = vim.split(c.body or '', '\n', { plain = true })[1] or ''
  if #first > signs.config.max_body then
    first = first:sub(1, signs.config.max_body) .. '…'
  end
  local tag = (c.pending and '[pending] ' or '')
    .. (c.subject_type == 'file' and '[file] ' or '')
    .. (c.outdated and '[outdated] ' or '')
  return string.format('%s@%s: %s', tag, c.author or '?', first)
end

--- Entry point.
---@param opts { mode: 'smart'|'add'|'edit', start_line: integer|nil, line: integer|nil }
--- smart: edit your comment under the cursor if any, else add.
function M.comment(opts)
  opts = opts or {}
  local mode = opts.mode or 'smart'
  local ctx, err = util.buf_context(0)
  if not ctx then
    return notify(err, vim.log.levels.WARN)
  end
  local lnum = vim.api.nvim_win_get_cursor(0)[1]

  with_current_pr(ctx.root, function(pr)
    if mode == 'add' then
      return start_add(ctx, pr, opts)
    end
    signs.ensure(pr, function()
      util.whoami(function(me)
        local mine = my_comments_at(pr, ctx.path, lnum, me)
        if #mine == 0 then
          if mode == 'edit' then
            return notify('No comment of yours on this line', vim.log.levels.WARN)
          end
          return start_add(ctx, pr, opts)
        elseif #mine == 1 then
          start_edit(ctx, pr, mine[1])
        else
          vim.ui.select(mine, {
            prompt = 'Edit which comment?',
            format_item = summarize,
          }, function(choice)
            if choice then
              start_edit(ctx, pr, choice)
            end
          end)
        end
      end)
    end)
  end)
end

---------------------------------------------------------------------------
-- Setup
---------------------------------------------------------------------------

function M.setup(opts)
  signs.setup(opts)

  -- Line to comment on from a user command invocation.
  local function target(cmd)
    if cmd.bang then
      return {} -- file-level
    elseif cmd.range == 0 then
      return { line = vim.api.nvim_win_get_cursor(0)[1] }
    end
    return { start_line = cmd.line1, line = cmd.line2 }
  end

  local function define(name, mode, desc)
    vim.api.nvim_create_user_command(name, function(cmd)
      local t = target(cmd)
      t.mode = mode
      -- A range or bang means "new comment here", never edit.
      if mode == 'smart' and (cmd.bang or cmd.range > 0) then
        t.mode = 'add'
      end
      M.comment(t)
    end, { range = true, bang = true, desc = desc })
  end

  -- :PRComment     edit your comment on the cursor line, else add one
  -- :'<,'>PRComment / :PRComment!   add (range / file-level)
  define('PRComment', 'smart', 'Edit or add a PR review comment')
  define('PRCommentAdd', 'add', 'Add a pending PR review comment')
  define('PRCommentEdit', 'edit', 'Edit your PR review comment on this line')

  vim.api.nvim_create_user_command('PRCommentRefresh', function()
    local ctx = util.buf_context(0)
    with_current_pr(ctx and ctx.root or vim.fn.getcwd(), function()
      signs.refresh()
    end)
  end, { desc = 'Refetch PR comments and redraw signs' })

  -- :PRSelect   -> pick among open PRs, :PRSelect! -> include closed/merged
  vim.api.nvim_create_user_command('PRSelect', function(cmd)
    M.select { all = cmd.bang }
  end, { bang = true, desc = 'Select the PR under review' })
end

return M
