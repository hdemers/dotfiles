return {
  {
    name = 'arduino',
    dir = '~/src/nvim/arduino',
    dependencies = {
      'stevearc/overseer.nvim',
    },
    config = function()
      require('arduino').setup()

      local overseer = require 'overseer'
      overseer.load_template 'misc.upload_sketch'
      overseer.load_template 'misc.compile_sketch'
      overseer.load_template 'misc.monitor_sketch'
    end,
  },
}
