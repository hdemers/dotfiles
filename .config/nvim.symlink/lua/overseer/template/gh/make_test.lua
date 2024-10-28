return {
  name = 'make-test',
  builder = function()
    return {
      cmd = { 'make' },
      args = { 'test' },
    }
  end,
  desc = 'Run make test',
}
