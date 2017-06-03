if exists('g:loaded_breakdown') || &compatible || v:version < 700
    finish
endif
let g:loaded_breakdown = 1

let s:save_cpo = &cpo
set cpo&vim

nno <silent> m<cr>   :<c-u>call breakdown#mark()<CR>
nno <silent> m<c-h>  :<c-u>call breakdown#clear()<CR>

nno <silent> m(      :<c-u>call breakdown#main(-1, 0)<CR>
nno <silent> m)      :<c-u>call breakdown#main(0, 0)<CR>

nno <silent> m{      :<c-u>call breakdown#main(-1, 1)<CR>
nno <silent> m}      :<c-u>call breakdown#main(0, 1)<CR>

let &cpo = s:save_cpo
