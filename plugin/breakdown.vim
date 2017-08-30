if exists('g:loaded_breakdown')
    finish
endif
let g:loaded_breakdown = 1

nno <silent> m<cr>   :<c-u>call breakdown#mark()<cr>
nno <silent> m<c-h>  :<c-u>call breakdown#clear()<cr>

nno <silent> m(      :<c-u>call breakdown#expand(-1, 0)<cr>
nno <silent> m)      :<c-u>call breakdown#expand(-1, 1)<cr>

nno <silent> m{      :<c-u>call breakdown#expand(0, 0)<cr>
nno <silent> m}      :<c-u>call breakdown#expand(0, 1)<cr>
