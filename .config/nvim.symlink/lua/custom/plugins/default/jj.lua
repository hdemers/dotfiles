return {
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
