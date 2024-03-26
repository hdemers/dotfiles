return {
  {
    'github/copilot.vim',
    lazy = false,
    init = function()
      -- Set the highlight group for copilot suggestions
      local apply_highlight = function()
        vim.api.nvim_set_hl(0, 'CopilotSuggestion', {
          link = 'Whitespace',
        })
      end
      apply_highlight()
      vim.api.nvim_create_autocmd('ColorScheme', {
        pattern = 'solarized',
        group = vim.api.nvim_create_augroup('CustomColorscheme', { clear = false }),
        callback = apply_highlight,
      })
    end,
  },
}
