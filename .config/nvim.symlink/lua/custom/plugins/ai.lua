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
  {
    'jackMort/ChatGPT.nvim',
    event = 'VeryLazy',
    opts = {
      popup_layout = {
        default = 'center',
        center = {
          width = '50%',
          height = '80%',
        },
        right = {
          width = '30%',
          width_settings_open = '50%',
        },
      },
      openai_params = {
        model = 'gpt-4',
        frequency_penalty = 0,
        presence_penalty = 0,
        max_tokens = 300,
        temperature = 0,
        top_p = 1,
        n = 1,
      },
      openai_edit_params = {
        model = 'gpt-4',
        frequency_penalty = 0,
        presence_penalty = 0,
        max_tokens = 300,
        temperature = 0,
        top_p = 1,
        n = 1,
      },
    },
    config = function(_, opts)
      require('chatgpt').setup(opts)
    end,
    dependencies = {
      'MunifTanjim/nui.nvim',
      'nvim-lua/plenary.nvim',
      'folke/trouble.nvim',
      'nvim-telescope/telescope.nvim',
    },
    keys = {
      {
        '<leader>hg',
        ':ChatGPT<CR>',
        desc = 'ChatGPT: [h]elp Chat[G]PT',
      },
    },
    init = function()
      -- Document key chains
      require('which-key').add {
        { '<leader>h', group = '[H]elp' },
      }
    end,
  },
  {
    'Aaronik/GPTModels.nvim',
    dependencies = {
      'MunifTanjim/nui.nvim',
      'nvim-telescope/telescope.nvim',
    },
    keys = {
      {
        '<leader>hc',
        ':GPTModelsChat<CR>',
        desc = 'ChatGPT: [h]elp [c]hat',
        mode = { 'n', 'v' },
      },
      -- {
      --   '<leader>ho',
      --   ':GPTModelsCode<CR>',
      --   desc = 'GPTModels: [h]elp c[o]de',
      --   mode = { 'n', 'v' },
      -- },
    },
  },
  {
    'robitx/gp.nvim',
    keys = {
      {
        '<leader>hn',
        ':GpChatNew popup<CR>',
        desc = 'GP: [h]elp [n]ew',
        mode = { 'n', 'v' },
      },
      {
        '<leader>ht',
        ':GpChatToggle popup<CR>',
        desc = 'GP: [h]elp [t]oggle',
        mode = { 'n', 'v' },
      },
      {
        '<leader>hf',
        ':GpChatFinder<CR>',
        desc = 'GP: [h]elp [f]ind',
        mode = { 'n' },
      },
      {
        '<leader>hd',
        ':GpChatDelete<CR>',
        desc = 'GP: [h]elp [d]elete',
        mode = { 'n' },
      },
    },
    opts = {},
    config = function(_, opts)
      require('gp').setup(opts)
    end,
  },
}
