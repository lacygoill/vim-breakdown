nno <silent> m<cr>   :<c-u>call breakdown#mark()<CR>
nno <silent> m<c-h>  :<c-u>call breakdown#clear()<CR>

nno <silent> m(      :<c-u>call breakdown#main(-1, 0)<CR>
nno <silent> m)      :<c-u>call breakdown#main(0, 0)<CR>

nno <silent> m{      :<c-u>call breakdown#main(-1, 1)<CR>
nno <silent> m} :<c-u>call breakdown#main(0, 1)<CR>
