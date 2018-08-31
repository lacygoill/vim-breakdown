if exists('g:loaded_breakdown')
    finish
endif
let g:loaded_breakdown = 1

nno  <silent><unique>  m<cr>   :<c-u>call breakdown#mark()<cr>
nno  <silent><unique>  m<c-h>  :<c-u>call breakdown#clear_match()<cr>

nno  <silent><unique>  m)      :<c-u>call breakdown#expand('simple', 'above')<cr>
nno  <silent><unique>  m}      :<c-u>call breakdown#expand('simple', 'below')<cr>

nno  <silent><unique>  m(      :<c-u>call breakdown#expand('bucket', 'above')<cr>
nno  <silent><unique>  m{      :<c-u>call breakdown#expand('bucket', 'below')<cr>

" TODO: If possible, use `append()` or `setline()` instead of `:norm` to draw a diagram.  It's faster.

" TODO: We should be able to create a diagram mixing simple branches and buckets.
" We would need 2 keys: one to set a simple branch, one for the two ends of a bucket.

" TODO: Add support for text written before diagram (instead of after){{{
"
" For the lhs use:    m((
"                     m() above the line, to the right of the diagram
"                     m)( below the line, to the left of the diagram
"                     m))
"
"                     m{{
"                     m{}
"                     m}{
"                     m}}
"
" We would have to change the mappings like this:
"
" nno <silent>   m((   :<c-u>call breakdown#main('bucket', 'above', 'before')<cr>
" nno <silent>   m()   :<c-u>call breakdown#main('bucket', 'above', 'after')<cr>
" nno <silent>   m)(   :<c-u>call breakdown#main('simple', 'above', 'before')<cr>
" nno <silent>   m))   :<c-u>call breakdown#main('simple', 'above', 'after')<cr>
"
" And adapt `draw()` and `populate_loclist()`.
"
" Example of bucket diagram:
"
"                                     search('=\%#>', 'bn', line('.'))
"                                            ├─────┘  ├──┘  ├───────┘
"                                            │        │     └ search in the current line only
"                                            │        │
"                                            │        └ backwards without moving the cursor and
"                                            │
"                                            └ match any `=[>]`, where `[]` denotes the
"                                              cursor's position
"
" Example of reverse bucket diagram:
"
"                                     search('=\%#>', 'bn', line('.'))
"                                            └─────┤  └──┤  └───────┤
"         match any `=[>]`, where `[]` denotes the ┘     │          │
"                                                        │          │
"                cursor's position                       │          │
"                backwards without moving the cursor and ┘          │
"                                                                   │
"                                   search in the current line only ┘
"
"
" Example of simple diagram:
"
"                                     search('=\%#>', 'bn', line('.'))
"                                            │        │     │
"                                            │        │     └ search in the current line only
"                                            │        │
"                                            │        └ backwards without moving the cursor and
"                                            │
"                                            └ match any `=[>]`, where `[]` denotes the cursor's position
"
" Example of reverse simple diagram:
"
"                                     search('=\%#>', 'bn', line('.'))
"                                            │        │     │
"   match any `=[>]`, where `[]` denotes the ┘        │     │
"   cursor's position                                 │     │
"                                                     │     │
"             backwards without moving the cursor and ┘     │
"                                                           │
"                           search in the current line only ┘
"}}}
