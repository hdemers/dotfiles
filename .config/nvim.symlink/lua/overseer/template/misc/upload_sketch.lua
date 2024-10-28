return {
  name = 'upload-sketch',
  builder = function()
    local file = vim.fn.expand '%:p'

    return {
      cmd = { 'arduino-cli' },
      args = { 'upload', file },
    }
  end,
  condition = {
    filetype = { 'arduino' },
  },
  desc = 'Upload arduino sketch',
}
