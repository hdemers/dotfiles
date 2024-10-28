return {
  name = 'deploy-branch',
  builder = function()
    return {
      cmd = { 'jenkins' },
      args = { 'deploy-branch' },
    }
  end,
  desc = 'Deploy branch',
}
