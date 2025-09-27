-- Neovim configuration with lualine
vim.opt.compatible = false
vim.opt.shortmess = "AI"

-- GUI options for neovide/gvim
if vim.g.neovide or vim.fn.has('gui_running') == 1 then
    vim.opt.langmenu = "en_US"
    vim.env.LANG = "en_US"
    vim.cmd([[
        source $VIMRUNTIME/delmenu.vim
        source $VIMRUNTIME/menu.vim
    ]])
    vim.opt.guioptions:remove('T')  -- tool
    vim.opt.guioptions:remove('m')  -- menu 
    vim.opt.guioptions:remove('r')  -- scroll
end

-- Install lazy.nvim plugin manager
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Setup plugins
require("lazy").setup({
  {
    'nvim-lualine/lualine.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function()
      -- Custom theme with our specific colors
      local custom_theme = {
        normal = {
          a = { fg = '#007C00', bg = '#A2E600' },
          b = { fg = '#c5c8c6', bg = '#373b41' },
          c = { fg = '#b4b7b4', bg = '#303030' },
          x = { fg = '#b4b7b4', bg = '#303030' },
          y = { fg = '#c5c8c6', bg = '#585858' },
          z = { fg = '#c5c8c6', bg = '#D0D0D0' }
        },
        insert = {
          a = { fg = '#373b41', bg = '#FFFFFF' },
          b = { fg = '#7CBCC0', bg = '#135C8C' },
          c = { fg = '#7CBCC0', bg = '#135C8C' },
          x = { fg = '#7CBCC0', bg = '#135C8C' },
          y = { fg = '#111111', bg = '#1486B5' },
          z = { fg = '#10537D', bg = '#8AD6FF' }
        },
        visual = {
          a = { fg = '#c5c8c6', bg = '#606060' },
          b = { fg = '#c5c8c6', bg = '#373b41' },
          c = { fg = '#b4b7b4', bg = '#1d1f21' },
          x = { fg = '#b4b7b4', bg = '#1d1f21' },
          y = { fg = '#c5c8c6', bg = '#373b41' },
          z = { fg = '#c5c8c6', bg = '#606060' }
        },
        replace = {
          a = { fg = '#ffffff', bg = '#88E0FF' },
          b = { fg = '#c5c8c6', bg = '#373b41' },
          c = { fg = '#b4b7b4', bg = '#1d1f21' },
          x = { fg = '#b4b7b4', bg = '#1d1f21' },
          y = { fg = '#c5c8c6', bg = '#373b41' },
          z = { fg = '#ffffff', bg = '#88E0FF' }
        },
        command = {
          a = { fg = '#c5c8c6', bg = '#606060' },
          b = { fg = '#c5c8c6', bg = '#373b41' },
          c = { fg = '#b4b7b4', bg = '#1d1f21' },
          x = { fg = '#b4b7b4', bg = '#1d1f21' },
          y = { fg = '#c5c8c6', bg = '#373b41' },
          z = { fg = '#c5c8c6', bg = '#606060' }
        },
        inactive = {
          a = { fg = '#c5c8c6', bg = '#606060' },
          b = { fg = '#c5c8c6', bg = '#373b41' },
          c = { fg = '#b4b7b4', bg = '#1d1f21' },
          x = { fg = '#b4b7b4', bg = '#1d1f21' },
          y = { fg = '#c5c8c6', bg = '#373b41' },
          z = { fg = '#c5c8c6', bg = '#606060' }
        }
      }
      
      -- Add tabline theme for normal and insert modes
      custom_theme.normal.tabline = {
        a = { fg = '#c5c8c6', bg = '#606060' },  -- buffers section
        b = { fg = '#c5c8c6', bg = '#303030' },  -- empty sections
        c = { fg = '#c5c8c6', bg = '#303030' },  -- middle section
        x = { fg = '#c5c8c6', bg = '#303030' },
        y = { fg = '#c5c8c6', bg = '#303030' },
        z = { fg = '#c5c8c6', bg = '#606060' }   -- tabs section
      }
      
      custom_theme.insert.tabline = {
        a = { fg = '#ffffff', bg = '#88E0FF' },  -- buffers section in insert mode
        b = { fg = '#c5c8c6', bg = '#303030' },
        c = { fg = '#c5c8c6', bg = '#303030' },
        x = { fg = '#c5c8c6', bg = '#303030' },
        y = { fg = '#c5c8c6', bg = '#303030' },
        z = { fg = '#ffffff', bg = '#88E0FF' }   -- tabs section in insert mode
      }
      
      -- Copy tabline theme to other modes
      custom_theme.visual.tabline = custom_theme.normal.tabline
      custom_theme.replace.tabline = custom_theme.insert.tabline
      custom_theme.command.tabline = custom_theme.normal.tabline
      custom_theme.inactive.tabline = custom_theme.normal.tabline
      
      require('lualine').setup({
        options = {
          theme = custom_theme,
          component_separators = { left = '\u{e0b1}', right = '\u{e0b3}'},
          section_separators = { left = '\u{e0b0}', right = '\u{e0b2}'},
          disabled_filetypes = {},
          always_divide_middle = true,
          globalstatus = false,
        },
        sections = {
          lualine_a = {'mode'},
          lualine_b = {'branch', 'diff', 'diagnostics'},
          lualine_c = {'filename'},
          lualine_x = {'encoding', 'fileformat', 'filetype'},
          lualine_y = {'progress'},
          lualine_z = {'location'}
        },
        inactive_sections = {
          lualine_a = {},
          lualine_b = {},
          lualine_c = {'filename'},
          lualine_x = {'location'},
          lualine_y = {},
          lualine_z = {}
        },
        tabline = {
          lualine_a = {
            {
              'buffers',
              buffers_color = {
                active = function()
                  local mode = vim.fn.mode()
                  if mode == 'i' or mode == 'ic' or mode == 'ix' then
                    return { fg = '#ffffff', bg = '#88E0FF' }
                  else
                    return { fg = '#c5c8c6', bg = '#606060' }
                  end
                end,
                inactive = { fg = '#808080', bg = '#606060' }
              }
            }
          },
          lualine_b = {},
          lualine_c = {},
          lualine_x = {},
          lualine_y = {},
          lualine_z = {
            {
              'tabs',
              tabs_color = {
                active = function()
                  local mode = vim.fn.mode()
                  if mode == 'i' or mode == 'ic' or mode == 'ix' then
                    return { fg = '#ffffff', bg = '#88E0FF' }
                  else
                    return { fg = '#c5c8c6', bg = '#606060' }
                  end
                end,
                inactive = { fg = '#808080', bg = '#606060' }
              }
            }
          }
        },
        extensions = {}
      })
    end
  }
})

-- Basic settings
vim.opt.laststatus = 2
vim.opt.showmode = false

-- Appearance
vim.cmd('colorscheme Tomorrow-Night-Bright')
vim.opt.guifont = "Source Code Pro"
vim.opt.showtabline = 2
vim.opt.number = true

-- Key mappings
vim.keymap.set('n', '<C-N><C-N>', ':set invnumber<CR>')
vim.opt.numberwidth = 5
vim.opt.cpoptions:append('n')

-- Highlights
vim.cmd([[
hi! VertSplit guifg=bg guibg=bg gui=NONE
hi! NonText guifg=bg
hi Normal ctermbg=black
]])

-- NERDTree settings
vim.g.NERDTreeWinPos = "right"
vim.keymap.set('n', '<C-N><C-T>', ':NERDTree')
vim.keymap.set('n', '<F6>', function()
  if vim.fn.exists('g:NERDTree') and vim.fn.get(vim.g.NERDTree, 'IsOpen', function() return 0 end)() then
    vim.cmd('NERDTreeClose')
  elseif vim.fn.bufexists(vim.fn.expand('%')) then
    vim.cmd('NERDTreeFind')
  else
    vim.cmd('NERDTree')
  end
end, { silent = true, expr = false })

-- Enable syntax and filetype
vim.cmd('syntax enable')
vim.cmd('filetype plugin on')

-- Search and wildmenu
vim.opt.path:append('**')
vim.opt.wildmenu = true

-- File browsing
vim.g.netrw_banner = 0
vim.g.netrw_browse_split = 4
vim.g.netrw_altv = 1
vim.g.netrw_liststyle = 3
vim.g.netrw_list_hide = ""
vim.g.netrw_list_hide = vim.g.netrw_list_hide .. ",\\(^\\|\\s\\s\\)\\zs\\.\\S\\+"

-- GitGutter colors
vim.g.gitgutter_override_sign_column_highlight = 0
vim.cmd([[
highlight clear SignColumn
highlight GitGutterAdd ctermfg=2
highlight GitGutterChange ctermfg=3
highlight GitGutterDelete ctermfg=1
highlight GitGutterChangeDelete ctermfg=4
]])