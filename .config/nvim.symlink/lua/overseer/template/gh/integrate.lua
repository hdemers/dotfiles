return {
  name = 'integrate',
  builder = function()
    return {
      cmd = { 'jenkins' },
      args = { 'integrate' },
    }
  end,
  desc = 'Integrate branch',
}
