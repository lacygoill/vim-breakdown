nno <silent> m<cr>   :<c-u>call breakdown#mark()<cr>
nno <silent> m<c-h>  :<c-u>call breakdown#clear()<cr>

nno <silent> m(      :<c-u>call breakdown#main(-1, 0)<cr>
nno <silent> m)      :<c-u>call breakdown#main(0, 0)<cr>

nno <silent> m{      :<c-u>call breakdown#main(-1, 1)<cr>
nno <silent> m}      :<c-u>call breakdown#main(0, 1)<cr>
