if exists('g:loaded_breakdown') || &compatible || v:version < 700
    finish
endif
let g:loaded_breakdown = 1

let s:save_cpo = &cpo
set cpo&vim

if empty(mapcheck('m<cr>', 'n')) && !hasmapto('<plug>(breakdown_mark)', 'n')
    nmap m<cr>                   <plug>(breakdown_mark)
endif
nno <silent> <plug>(breakdown_mark)                 :<c-u>call breakdown#mark()<cr>

if empty(mapcheck('m<bs>', 'n')) && !hasmapto('<plug>(breakdown_clear)', 'n')
    nmap m<bs>                   <plug>(breakdown_clear)
endif
nno <silent> <plug>(breakdown_clear)                :<c-u>call breakdown#clear()<cr>

if empty(mapcheck('m(', 'n')) && !hasmapto('<plug>(breakdown_non_aligned_above)', 'n')
    nmap m(                   <plug>(breakdown_non_aligned_above)
endif
nno <silent> <plug>(breakdown_non_aligned_above)    :<c-u>call breakdown#main(-1,0)<cr>

if empty(mapcheck('m)', 'n')) && !hasmapto('<plug>(breakdown_non_aligned_below)', 'n')
    nmap m)                   <plug>(breakdown_non_aligned_below)
endif
nno <silent> <plug>(breakdown_non_aligned_below)    :<c-u>call breakdown#main(0,0)<cr>

if empty(mapcheck('m{', 'n')) && !hasmapto('<plug>(breakdown_aligned_above)', 'n')
    nmap m{                   <plug>(breakdown_aligned_above)
endif
nno <silent> <plug>(breakdown_aligned_above)        :<c-u>call breakdown#main(-1,1)<cr>

if empty(mapcheck('m}', 'n')) && !hasmapto('<plug>(breakdown_aligned_below)', 'n')
    nmap m}                   <plug>(breakdown_aligned_below)
endif
nno <silent> <plug>(breakdown_aligned_below)        :<c-u>call breakdown#main(0,1)<cr>

let &cpo = s:save_cpo
