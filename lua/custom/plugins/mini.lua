return {
  {
    'echasnovski/mini.nvim',
    config = function()
      require('mini.ai').setup { n_lines = 500 }
      require('mini.surround').setup {
        mappings = {
          add = 'gsa',
          delete = 'gsd',
          replace = 'gsr',
          find = 'gsf',
          find_left = 'gsF',
          highlight = 'gsh',
          update_n_lines = 'gsn',
          suffix_last = 'l',
          suffix_next = 'n',
        },
      }
      local ms = require 'mini.statusline'

      ms.setup {
        use_icons = vim.g.have_nerd_font,
        set_vim_settings = true,
        content = {
          active = function()
            local mode, mode_hl = ms.section_mode { trunc_width = 4000 }

            local git = ms.section_git { trunc_width = 40 }

            local filename = ms.section_filename { trunc_width = 140 }

            local location = '%l:%c'

            return ms.combine_groups {
              { hl = mode_hl, strings = { mode } },
              { hl = 'MiniStatuslineDevinfo', strings = { git } },
              '%<',
              { hl = 'MiniStatuslineFilename', strings = { filename } },
              '%=',
              { hl = mode_hl, strings = { location, ' %P' } },
            }
          end,
        },
      }
    end,
  },
}
-- vim: ts=2 sts=2 sw=2 et
