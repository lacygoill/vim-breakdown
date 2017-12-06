if exists('g:loaded_breakdown')
    finish
endif
let g:loaded_breakdown = 1

nno <silent><unique> m<cr>   :<c-u>call breakdown#mark()<cr>
nno <silent><unique> m<c-h>  :<c-u>call breakdown#clear()<cr>

nno <silent><unique> m)      :<c-u>call breakdown#expand(-1, 0)<cr>
nno <silent><unique> m(      :<c-u>call breakdown#expand(-1, 1)<cr>

nno <silent><unique> m}      :<c-u>call breakdown#expand(0, 0)<cr>
nno <silent><unique> m{      :<c-u>call breakdown#expand(0, 1)<cr>

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
" nno <silent> m((      :<c-u>call breakdown#main(-1, -1, 0)<cr>
" nno <silent> m()      :<c-u>call breakdown#main(-1, 0, 0)<cr>
" nno <silent> m)(      :<c-u>call breakdown#main(0, -1, 0)<cr>
" nno <silent> m))      :<c-u>call breakdown#main(0, 0, 0)<cr>
"
" And adapt `draw()` and `populate_loclist()`.
" Pb:
" It would still be hard for us to align the text with the pieces of the
" diagram. Maybe it would be better
"
" Example of aligned diagram:
"
"                                     search('=\%#>', 'bn', line('.'))
"                                            └─────┤  └──┤  └───────┤
"                                                  │     │          └ search in the current line only
"                                                  │     └─────────── backwards without moving the cursor and
"                                                  └───────────────── match any `=[>]`, where `[]` denotes the
"                                                                     cursor's position
"
" Example of reverse aligned diagram:
"
"                                     search('=\%#>', 'bn', line('.'))
"                                            ├─────┘  ├──┘  ├───────┘
" match any `=[>]`, where `[]` denotes the ──┘        │     │
" cursor's position                                   │     │
" backwards without moving the cursor and ────────────┘     │
" search in the current line only ──────────────────────────┘
"
" Pb:
" What if the text is too long?
" Should the ending branch begin from the left or the right of a bucket?
" Maybe we should install mappings which would toggle the layout of all the
" ending branches in a diagram...
"
"                                       don't maximize the window if the last visited window
"                                       (winnr('#')) was a preview window ──────────────────────┐
"                                                                                               │
"                                                        ┌──────────────────────────────────────┤
"                        if &l:buftype !=# 'quickfix' && !getwinvar(winnr('#'), '&previewwindow')
"
" Long ending branches are ugly:
"     '<,'>s/\v^\s*"\s*\zs(.{-})(\s*)(─+)/\=repeat(' ', strchars(submatch(3))).submatch(1).submatch(2)/
"
" … this substitution should convert a reverse aligned diagram (with possible
" ugly ending branches), into a reverse non-aligned diagram.
"
"
"
" Example of non-aligned diagram:
"
"                                     search('=\%#>', 'bn', line('.'))
"                                            │        │     │
"                                            │        │     └─ search in the current line only
"                                            │        └─ backwards without moving the cursor and
"                                            └─ match any `=[>]`, where `[]` denotes the cursor's position
"
" Example of reverse non-aligned diagram:
"
"                                     search('=\%#>', 'bn', line('.'))
"                                            │        │     │
"   match any `=[>]`, where `[]` denotes the ┘        │     │
"   cursor's position                                 │     │
"             backwards without moving the cursor and ┘     │
"                           search in the current line only ┘
"
" Pb2:
" Wouldn't it be better for our current aligned diagram to look this:
"
"                                     search('=\%#>', 'bn', line('.'))
"                                            └─────┤  └──┤  └───────┤
"                                                  │     │          └ search in the current line only
"                                                  │     │
"                                                  │     └ backwards without moving the cursor and
"                                                  │
"                                                  └ match any `=[>]`, where `[]` denotes the
"                                                    cursor's position
"
" Pro:
" more consistent with the other diagrams
" more space to write
"
" Con:
" less readable (unless we add empty lines between branches)
"
" NOTE:
" If we end up using this new type of diagram, we should stop talking of
" `aligned` diagrams. `bucket` diagrams instead?
"}}}
