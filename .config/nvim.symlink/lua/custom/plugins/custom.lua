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
  {
    name = 'ntfy',
    dir = '~/src/nvim/ntfy',
    config = function()
      local ntfy = require 'ntfy'
      ntfy.setup()
    end,
  },
  {
    name = 'misc',
    dir = '~/src/nvim/misc',
    config = function()
      require('misc').setup()
    end,
  },
}
