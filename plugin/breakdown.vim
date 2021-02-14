vim9script noclear

if exists('loaded') | finish | endif
var loaded = true

nno <unique> m<cr> <cmd>call breakdown#mark()<cr>
nno <unique> m<c-h> <cmd>call breakdown#clearMatch()<cr>

nno <unique> m) <cmd>call breakdown#expand('simple', 'above')<cr>
nno <unique> m} <cmd>call breakdown#expand('simple', 'below')<cr>

nno <unique> m( <cmd>call breakdown#expand('bucket', 'above')<cr>
nno <unique> m{ <cmd>call breakdown#expand('bucket', 'below')<cr>

# Why not `+^`?{{{
#
# I often press `g^` by accident, which atm makes us focus the first tabpage.
# Too distracting.
#}}}
nno <expr><unique> +v breakdown#putErrorSignSetup('below')
nno <expr><unique> +V breakdown#putErrorSignSetup('above')

xno <unique> +v <c-\><c-n><cmd>call breakdown#putV('below')<cr>
xno <unique> +V <c-\><c-n><cmd>call breakdown#putV('above')<cr>

# TODO: If possible, use `append()` or `setline()` instead of `:norm` to draw a diagram.  It's faster.

# TODO: We should be able to create a diagram mixing simple branches and buckets.
# We would need 2 keys: one to set a simple branch, one for the two ends of a bucket.

# TODO: Add support for text written before diagram (instead of after){{{
#
# For the lhs use:    m((
#                     m() above the line, to the right of the diagram
#                     m)( below the line, to the left of the diagram
#                     m))
#
#                     m{{
#                     m{}
#                     m}{
#                     m}}
#
# We would have to change the mappings like this:
#
#     nno m(( <cmd>call breakdown#main('bucket', 'above', 'before')<cr>
#     nno m() <cmd>call breakdown#main('bucket', 'above', 'after')<cr>
#     nno m)( <cmd>call breakdown#main('simple', 'above', 'before')<cr>
#     nno m)) <cmd>call breakdown#main('simple', 'above', 'after')<cr>
#
# And adapt `draw()` and `populate_loclist()`.
#
# Example of bucket diagram:
#
#                                     search('=\%#>', 'bn', line('.'))
#                                            ├─────┘  ├──┘  ├───────┘
#                                            │        │     └ search in the current line only
#                                            │        │
#                                            │        └ backwards without moving the cursor and
#                                            │
#                                            └ match any `=[>]`, where `[]` denotes the
#                                              cursor's position
#
# Example of reverse bucket diagram:
#
#                                     search('=\%#>', 'bn', line('.'))
#                                            └─────┤  └──┤  └───────┤
#         match any `=[>]`, where `[]` denotes the ┘     │          │
#                                                        │          │
#                cursor's position                       │          │
#                backwards without moving the cursor and ┘          │
#                                                                   │
#                                   search in the current line only ┘
#
#
# Example of simple diagram:
#
#                                     search('=\%#>', 'bn', line('.'))
#                                            │        │     │
#                                            │        │     └ search in the current line only
#                                            │        │
#                                            │        └ backwards without moving the cursor and
#                                            │
#                                            └ match any `=[>]`, where `[]` denotes the cursor's position
#
# Example of reverse simple diagram:
#
#                                         search('=\%#>', 'bn', line('.'))
#                                                │        │     │
#       match any `=[>]`, where `[]` denotes the ┘        │     │
#       cursor's position                                 │     │
#                                                         │     │
#                 backwards without moving the cursor and ┘     │
#                                                               │
#                               search in the current line only ┘

