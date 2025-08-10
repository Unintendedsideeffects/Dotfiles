" Minimal Flexoki-like colorscheme placeholder for Vim/Neovim
hi clear
if exists("syntax_on")
  syntax reset
endif
let g:colors_name = "flexoki"

set background=dark
hi Normal guifg=#d3c6aa guibg=#100f0f ctermfg=250 ctermbg=233
hi Comment guifg=#7c7a7a ctermfg=243
hi Identifier guifg=#5b9cff ctermfg=75
hi Statement guifg=#ffb454 ctermfg=215
hi PreProc guifg=#d088ff ctermfg=177
hi Type guifg=#7f8b00 ctermfg=100
hi Constant guifg=#d14 ctermfg=167
hi Special guifg=#2dd4bf ctermfg=79
hi CursorLine guibg=#1d1c1c ctermbg=234
hi LineNr guifg=#7c7a7a guibg=#100f0f ctermfg=243 ctermbg=233
hi StatusLine guifg=#100f0f guibg=#ffb454 ctermfg=233 ctermbg=215
