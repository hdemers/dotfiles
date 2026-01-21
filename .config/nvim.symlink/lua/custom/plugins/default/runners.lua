return {
  {
    'akinsho/toggleterm.nvim',
    version = '*',
    opts = {
      open_mapping = [[<c-\>]],
      direction = 'vertical',
      size = 180,
    },
    cmd = { 'ToggleTerm' },
    keys = {
      {
        [[<c-\>]],
      },
      {
        '<leader>bd',
        function()
          local Terminal = require('toggleterm.terminal').Terminal
          local box_name = os.getenv 'DBX_CONTAINER_NAME'
          Terminal:new({
            direction = 'vertical',
            cmd = 'distrobox enter ' .. box_name .. ' -- zsh',
            hidden = false,
            float_opts = { width = 60, height = 30 },
          }):open()
        end,
        desc = '[b]uffer terminal into [d]istrobox',
      },
    },
  },
}
