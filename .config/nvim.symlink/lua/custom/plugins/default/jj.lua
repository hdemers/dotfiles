return {
  {
    dir = '/home/hdemers/Projets/nvim/jj-log',
    cond = function()
      return not vim.g.use_legacy_jj
    end,
    config = function()
      local function rebase_octopus(state, _ctx)
        require('jujutsu.utils').run_jj_cmd('rebase-octopus', nil, { notify = false })
      end
      local jj = require 'jujutsu'

      local function smart_log()
        if jj.is_jujutsu_repo() then
          jj.jujutsu_flog()
        else
          vim.cmd 'Flog'
        end
      end

      local function smart_history()
        if jj.is_jujutsu_repo() then
          jj.jujutsu_file_history()
        else
          vim.cmd 'DiffviewFileHistory %'
        end
      end

      vim.keymap.set('n', '<leader>ji', jj.jujutsu_new, { desc = 'Insert new Jujutsu change' })
      vim.keymap.set('n', '<leader>gl', smart_log, { desc = 'Git/Jujutsu log (smart)' })
      vim.keymap.set('n', '<leader>gh', smart_history, { desc = 'Diffview/Jujutsu file history (smart)' })

      jj.setup {
        debug = false,
        highlights = {
          bookmarks = {
            ['dev'] = 'JjLogDev',
            ['staging'] = 'JjLogDev',
          },
        },
        hooks = {
          post_rebase_applied = rebase_octopus,
          post_bookmark_moved = rebase_octopus,
        },
        keys = {
          ['id'] = {
            action = 'new',
            opts = { target = 'dev' },
            desc = 'New commit after dev',
          },
          ['gp'] = {
            fn = function(_, _)
              require('jujutsu.utils').run_jj_cmd('push-my-shared-branches', nil)
            end,
            desc = 'Push my shared branches',
          },
          ['cD'] = {
            fn = function(state, ctx)
              local utils = require 'jujutsu.utils'
              local ids = utils.resolve_ids(ctx.item)
              if #ids == 0 then
                vim.notify('No revisions found for ' .. ctx.item, vim.log.levels.WARN)
                return
              end
              utils.cancel_debounce()
              local total, completed = #ids, 0
              local fidget_ok, fidget = pcall(require, 'fidget')
              for index, id in ipairs(ids) do
                local progress = fidget_ok
                    and fidget.progress.handle.create {
                      title = 'Jujutsu',
                      message = total > 1
                          and string.format('Queued: %s (%d/%d)', id, index, total)
                        or string.format('Queued: %s', id),
                      lsp_client = { name = 'cdescribe' },
                    }
                  or nil
                utils.enqueue(function(on_done)
                  if progress then
                    progress.message = total > 1
                        and string.format(
                          'Generating description for %s (%d/%d)...',
                          id,
                          index,
                          total
                        )
                      or string.format('Generating description for %s...', id)
                  end
                  vim.system({ 'cdescribe', id }, { cwd = state.cwd }, function(obj)
                    vim.schedule(function()
                      if progress then
                        progress:finish()
                      end
                      if obj.code ~= 0 then
                        local err = (obj.stderr ~= '' and obj.stderr)
                          or obj.stdout
                          or 'unknown error'
                        vim.notify(
                          'cdescribe failed for ' .. id .. ': ' .. err,
                          vim.log.levels.ERROR
                        )
                      end
                      completed = completed + 1
                      if completed == total then
                        utils.refresh_log()
                        if total > 1 then
                          vim.notify(
                            string.format('Finished %d descriptions.', total),
                            vim.log.levels.INFO
                          )
                        end
                      end
                      on_done()
                    end)
                  end)
                end)
              end
            end,
            desc = 'AI describe commit',
          },
        },
      }
    end,
  },
  {
    'julienvincent/hunk.nvim',
    cmd = { 'DiffEditor' },
    config = function()
      require('hunk').setup()
    end,
  },
  {
    'rafikdraoui/jj-diffconflicts',
    cmd = { 'JJDiffConflicts' },
  },
  { 'avm99963/vim-jjdescription' },
}
