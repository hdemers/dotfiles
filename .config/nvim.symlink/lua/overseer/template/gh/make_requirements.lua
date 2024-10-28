return {
  name = 'make-requirements',
  builder = function()
    return {
      cmd = { 'make' },
      args = { 'requirements.txt' },
    }
  end,
  desc = 'Run make requirements.txt',
}
