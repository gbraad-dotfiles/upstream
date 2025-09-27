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
      require('lualine').setup({
        options = {
          theme = 'powerline',
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
          lualine_a = {'buffers'},
          lualine_b = {},
          lualine_c = {},
          lualine_x = {},
          lualine_y = {},
          lualine_z = {'tabs'}
        },
        extensions = {}
      })
    end
  }
})

-- Basic settings
vim.opt.laststatus = 2
vim.opt.showmode = false

-- Fix tabline colors with autocmds
vim.api.nvim_create_autocmd({"ModeChanged", "VimEnter"}, {
  callback = function()
    -- Delay to let lualine fully load first
    vim.defer_fn(function()
      local mode = vim.fn.mode()
      if mode == 'i' then
        vim.cmd([[
          hi lualine_a_buffers_active ctermfg=15 ctermbg=39 guifg=#ffffff guibg=#88E0FF
          hi lualine_z_tabs_active ctermfg=15 ctermbg=39 guifg=#ffffff guibg=#88E0FF
        ]])
        -- Set correct colors for insert mode (blue)
        vim.cmd('hi! lualine_transitional_lualine_a_buffers_active_to_lualine_b_tabline ctermfg=39 guifg=#88E0FF')
        vim.cmd('hi! lualine_transitional_lualine_z_tabs_active_to_lualine_c_tabline ctermfg=39 guifg=#88E0FF')
        vim.cmd('hi! lualine_transitional_lualine_z_tabs_active_to_lualine_c_normal ctermfg=39 guifg=#88E0FF')
        -- Set all buffer-related AND tab-related transitional highlights
        for _, hl in ipairs(vim.fn.getcompletion('lualine_transitional', 'highlight')) do
          if string.match(hl, 'buffer') or string.match(hl, 'tabs') then
            vim.cmd('hi! ' .. hl .. ' ctermfg=39 guifg=#88E0FF')
          end
        end
      else
        vim.cmd([[
          hi lualine_a_buffers_active ctermfg=15 ctermbg=241 guifg=#c5c8c6 guibg=#606060
          hi lualine_z_tabs_active ctermfg=15 ctermbg=241 guifg=#c5c8c6 guibg=#606060
        ]])
        -- Set correct colors for normal mode (grey)
        vim.cmd('hi! lualine_transitional_lualine_a_buffers_active_to_lualine_b_tabline ctermfg=241 guifg=#606060')
        vim.cmd('hi! lualine_transitional_lualine_z_tabs_active_to_lualine_c_tabline ctermfg=241 guifg=#606060')
        vim.cmd('hi! lualine_transitional_lualine_z_tabs_active_to_lualine_c_normal ctermfg=241 guifg=#606060')
        -- Set all buffer-related transitional highlights  
        for _, hl in ipairs(vim.fn.getcompletion('lualine_transitional', 'highlight')) do
          if string.match(hl, 'buffer') then
            vim.cmd('hi! ' .. hl .. ' ctermfg=241 guifg=#606060')
          end
        end
      end
    end, 100)
  end
})

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

" Fix tabline colors - background should be #606060, separators should be light grey
hi TabLine ctermfg=250 ctermbg=241 guifg=#c5c8c6 guibg=#606060
hi TabLineFill ctermfg=241 ctermbg=241 guifg=#606060 guibg=#606060
hi TabLineSel ctermfg=15 ctermbg=241 guifg=#ffffff guibg=#606060

" Override lualine tabline colors to prevent green bleeding
hi lualine_a_buffers_active_buffers ctermfg=250 ctermbg=241 guifg=#ffffff guibg=#606060
hi lualine_a_buffers_inactive_buffers ctermfg=8 ctermbg=241 guifg=#808080 guibg=#606060
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