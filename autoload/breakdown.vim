fu! breakdown#clear() abort "{{{1
    if exists('w:bd_marks.id')
        call matchdelete(w:bd_marks.id)
        call remove(w:bd_marks, 'id')
    endif
endfu

fu! s:comment(what, where, dir, hm_to_draw) abort "{{{1

" This function is called once or twice per line of the diagram.
" Twice if we're in a buffer whose commentstring has 2 parts.
"
" Example:    <!-- html text -->
"             ^              ^
"             first part     2nd part
"
" Its purpose is to comment each line of the diagram.
" `what` is either the lhs or the rhs of a commentstring.

    " Before beginning commenting the lines of the diagram, make sure the cursor
    " is on the line we're describing.
    exe 'norm! '. w:bd_marks.coords[0].line .'G'

    let indent = repeat(' ', indent('.'))

    " iterate over the lines of the diagram
    for i in range(0, a:hm_to_draw)
        " move the cursor in the right direction
        exe (a:dir ==# -1 ? '-' : '+')

        let rep = a:where is# 'left'
        \?            indent . a:what
        \:            substitute(getline('.'), '$', ' '.a:what, '')

        call setline(line('.'), rep)
    endfor
endfu

fu! s:draw(align, dir, coord, hm_to_draw) "{{{1
    " This function draws a piece of the diagram.
    let [ align, dir, coord, hm_to_draw ] = [ a:align, a:dir, a:coord, a:hm_to_draw ]

    " reposition cursor before drawing the next piece
    exe 'norm! '. coord.line .'G'. coord.col . '|'

    if align
        " get the index of the current marked character inside the list of
        " coordinates (w:bd_marks.coords)
        let i = index(w:bd_marks.coords, coord)
        " get the width of the `───` segment to draw above the item to describe
        let w = w:bd_marks.coords[i+1].col - coord.col - 1
        " get the width of the `───` segment to draw next to its description
        let ww = w:bd_marks.coords[-1].col - w:bd_marks.coords[i+1].col

        if dir ==# -1
            " draw `┌───┤`
            exe "norm! kR\u250c".repeat("\u2500", w)."\u2524"
            " draw the `│` column
            for i in range(1, hm_to_draw - 1)
                exe "norm! kr\u2502"
            endfor
            " draw `┌────`
            exe "norm! kR\u250c".repeat("\u2500", ww).' '

        else
            " draw `└───┤`
            exe "norm! jR\u2514".repeat("\u2500", w)."\u2524"
            " draw the `│` column
            for i in range(1, hm_to_draw - 1)
                exe "norm! jr\u2502"
            endfor
            " draw `└────`
            exe "norm! jR\u2514".repeat("\u2500", ww).' '
        endif

    else
        if dir ==# -1
            " draw the `│` column
            for i in range(1, hm_to_draw + 1)
                exe "norm! kr\u2502"
            endfor
            exe "norm! R\u250c "
        else
            " draw the `│` column
            for i in range(1, hm_to_draw + 1)
                exe "norm! jr\u2502"
            endfor
            exe "norm! R\u2514 "
        endif
    endif
endfu

fu! breakdown#expand(dir, align) abort "{{{1
    " don't try to draw anything if we don't have any coordinates
    if !exists('w:bd_marks.coords')
        return
    endif

    let [ dir, align ] = [ a:dir, a:align ]
    " we save the coordinates, because we may update them during the expansion
    " it happens when the diagram must be drawn above (not below)
    let coords_save = deepcopy(w:bd_marks.coords)

    " if we want to draw the diagram in which the items are aligned, the number
    " of marked characters must be even, not odd
    if align && len(w:bd_marks.coords) % 2 ==# 1
        echohl ErrorMsg
        echo '[breakdown] number of marked characters must be even'
        echohl None
        return
    endif

    " make sure 've' allows us to draw freely
    " also, make sure 'tw' and 'wm' don't break a long line
    let [ ve_save, tw_save, wm_save ] = [ &ve, &l:tw, &l:wm ]
    setl ve=all tw=0 wm=0

    " initialize empty location list
    let w:bd_marks.loclist = []

    " we sort the coordinates according to their column number, because
    " there's no guarantee that we marked the characters in order from left to
    " right
    call sort(w:bd_marks.coords, {x,y -> x.col - y.col})

    " In a diagram in which the descriptions are aligned, every 2 consecutive
    " marked characters stand for one piece of the latter.
    " Therefore, the `for` loop which will progressively draw the diagram must
    " iterate over half of the coordinates.

    let coords_to_process = align
    \?                          filter(deepcopy(w:bd_marks.coords), 'v:key % 2 ==# 0')
    \:                          deepcopy(w:bd_marks.coords)
    "                           │
    "                           └── why `deepcopy()`?
    "                           because we may update the line coordinates, later, inside `coords_to_process`
    "                           (necessary if the diagram is drawn above)
    "                           and if we do, without `deepcopy()`, it would also affect `w:bd_marks.coords`
    "                           because they would be the same list:

    "                                   echo w:bd_marks.coords is coords_to_process    →    1

    "                           without `deepcopy()`, we would need to remove `coords_to_process` from
    "                           the next `for` loop:

    "                                   for coord in coords_to_process + w:bd_marks.coords
    "                                   →
    "                                   for coord in w:bd_marks.coords

    "                           … to avoid that the elements are incremented twice, instead of once

    "                           but even then, the plugin wouldn't work as expected,
    "                           because when we would try to draw an aligned diagram above a line,
    "                           it would be too high


    " How Many lines of the diagram are still TO be DRAWn
    let hm_to_draw = len(coords_to_process)

    " make sure the cursor is on the line containing marked characters
    exe 'norm! '.w:bd_marks.coords[0].line.'G'

    " open enough new lines to draw diagram
    call append(line('.') + dir, repeat([''], hm_to_draw + 1))

    " if we've just opened new lines above (instead of below) …
    if dir ==# -1
        " … the address of the line of the marked characters must be updated
        for coord in coords_to_process + w:bd_marks.coords
        "                              │
        "                              └── `coords_to_process` is only a copy
        "                                  of (a subset of) `w:bd_marks.coords`
        "                                  we also need to update the original coordinates

            " … increment it with `len(coords_to_process) + 1`
            let coord.line += len(coords_to_process) + 1
        endfor
    endif

    " if there's a commentstring, comment the diagram lines (left side)
    " except in a markdown buffer, because a diagram won't cause errors in
    " a note file, so there's no need to
    if !empty(&l:cms) && index(['markdown', 'text'], &ft) ==# -1
        let [ cms_left, cms_right ] = split(&l:cms, '%s', 1)
        call s:comment(cms_left, 'left', dir, hm_to_draw)
    endif

    for coord in coords_to_process
        " draw a piece of the diagram
        call s:draw(align, dir, coord, hm_to_draw)

        " populate the location list
        call s:populate_loclist(align, coord, dir, hm_to_draw)

        let hm_to_draw -= 1
    endfor

    " set location list
    call setloclist(0, w:bd_marks.loclist)
    call setloclist(0, [], 'a', {'title': 'Breakdown'})

    " if there's a commentstring which has a non empty right part,
    " comment the right side of the diagram lines
    if exists('cms_right') && !empty(cms_right)
        call s:comment(cms_right, 'right', dir, len(coords_to_process))
        "                                       │
        "                                       └── can't use `hm_to_draw` again
        "                                           because the variable has been decremented
        "                                           in the previous for loop
    endif

    sil! call lg#motion#repeatable#make#set_last_used(']l', {'bwd': ',', 'fwd': ';'})

    " clear match
    call breakdown#clear()

    " restore the original values of the options we changed
    let [ &ve, &l:tw, &l:wm ] = [ ve_save, tw_save, wm_save ]
    " restore the coordinates in case we changed the addresses of the lines
    " during the expansion; this restoration allows us to re-expand correctly
    " the diagram later (after an undo), if we hit the wrong mapping by accident
    let w:bd_marks.coords = coords_save
endfu

fu! breakdown#mark() abort "{{{1
    " if `w:bd_marks.id` doesn't exist, initialize `w:bd_marks`
    if !exists('w:bd_marks.id')
        let w:bd_marks = {
        \                  'coords'  : [],
        \                  'pattern' : '',
        \                  'id'      :  0,
        \                }
    elseif w:bd_marks.id
        " otherwise if it exists and is different from 0
        " delete the match because we're going to update it:
        " we don't want to add a new match besides the old one
        call matchdelete(w:bd_marks.id)
        " and add a bar at the end of the pattern, to prepare for a new
        " piece
        let w:bd_marks.pattern .= '|'
    endif

    " If we're on the same line as the previous marked characters…
    if !empty(w:bd_marks.coords) && line('.') ==# w:bd_marks.coords[0].line

        " … and if the current position is already marked, then instead of
        " readding it as a mark, remove it (toggle).
        if index(w:bd_marks.coords, {'line' : line('.'), 'col' : virtcol('.')} ) >= 0

            call filter(w:bd_marks.coords, { i,v ->  v !=# {'line' : line('.'), 'col' : virtcol('.')}  })
        else

        " … otherwise add the current position to the list of coordinates

            let w:bd_marks.coords += [{
                                      \ 'line' : line('.'),
                                      \ 'col'  : virtcol('.'),
                                      \ }]
        endif

    else
    " Otherwise, if we're marking a character on a different line, reset
    " completely the list of coordinates.

        let w:bd_marks.coords = [{
                                 \ 'line' : line('.'),
                                 \ 'col'  : virtcol('.'),
                                 \ }]
    endif

    " build a pattern using the coordinates in `w:bd_marks.coords`
    "
    " NOTE:
    " Every time we need to make a copy of the coordinates, we have to use
    " `deepcopy()`. We can't use `copy()`, because each item in the list of
    " coordinates is a dictionary, not just a simple data structure such as
    " a number or a string.
    "
    " `copy()` would create a new list of coordinates, but whose items would
    " be identical to the original list.
    "
    " So, changing an item in the copy would immediately affect the original list.
    "
    " However, we probably don't need `deepcopy()` here. Only later when we
    " may update the 'line' key of each dictionary (happens when we expand the
    " diagram above).
    "
    " Here, we don't change any key of the dictionaries inside the list
    " `w:bd_marks.coords`. We simply use each dictionary to build a string
    " which populates a list (the one returned by `map()`).
    "
    " So, why `deepcopy()` instead of `copy()`?
    "
    "         1. better be safe than sorry
    "         2. consistency (`deepcopy()` later → `deepcopy()` now)

    let w:bd_marks.pattern = '\v'.join(map(deepcopy(w:bd_marks.coords),
    \                                      { i,v -> '%'.v.line.'l%'.v.col.'v.' }),
    \                                  '|')

    " create a match and store its id in `w:bd_marks.id`
    let w:bd_marks.id = !empty(w:bd_marks.coords)
    \?                      matchadd('SpellBad', w:bd_marks.pattern)
    \:                      0
endfu

fu! s:populate_loclist(align, coord, dir, hm_to_draw) abort "{{{1
    let [ align, coord, dir, hm_to_draw ] = [ a:align, a:coord, a:dir, a:hm_to_draw ]

    " Example of aligned diagram:
    "
    "     search('=\%#>', 'bn', line('.'))
    "            └─────┤  └──┤  └───────┤
    "                  │     │          └ search in the current line only
    "                  │     └─────────── backwards without moving the cursor and
    "                  └───────────────── match any `=[>]`, where `[]` denotes the
    "                                     cursor's position

    " NOTE:
    " When we stored the position of the marked characters, we've used `virtcol()`,
    " so `coord.col` is a visual column, not a byte index.
    " But we need the byte index of the beginning of a line in the diagram.
    "
    " If there are multibyte characters before a marked character, does it cause
    " an issue for the byte index of the beginning of a line in the diagram in
    " the location list?
    "
    " No. Because before the beginning of a line in the diagram, there are only
    " spaces (and optionally comment characters).
    " And spaces aren't multibyte. So, the byte index of the beginning of
    " a line in the diagram matches the visual column of the corresponding
    " marked character.

        if align
            " We are going to store the byte index of the character where we
            " want the cursor to be positioned.
            " To compute this byte index, we first need to know the index of
            " the first of the 2 marked characters from which we draw a piece
            " of the diagram; the one above/below `└`/`┌`.

            let i = index(w:bd_marks.coords, coord)

            let col  = w:bd_marks.coords[i+1].col + ((len(w:bd_marks.coords)/2 - hm_to_draw))*2
            "          │                            │
            "          │                            └── before `└`/`┌`, there could be some `│`:
            "          │                                add 2 bytes for each of them
            "          │
            "          └── byte index of the next marked character (the one above/below `┤`)
            " NOTE:
            " The weight of our multibyte characters is 3, so why do we add only 2 bytes for each of them?
            " Because with `coord.col`, we already added one byte for each of them.

            let col += 3*(w:bd_marks.coords[-1].col - w:bd_marks.coords[i+1].col) + (3*1)+1
            "          │                                                            │
            "          │                                                            └── add 4 as a fixed offset
            "          └── add 3 bytes for every character in the `└──…` segment
        else
            let col  = coord.col + 2*((len(w:bd_marks.coords) - hm_to_draw)) + (1*2)+1
            "          │           │                                           │
            "          │           │                                           └── add 3 as a fixed offset
            "          │           └── before `└`, there could be some `│`: add 2 bytes for each of them
            "          └── number of bytes up to `└`/marked character
        endif

        call add(w:bd_marks.loclist, {
                                     \ 'bufnr' : bufnr('%'),
                                     \ 'lnum'  : coord.line + (dir ==# -1 ? -hm_to_draw - 1 : hm_to_draw + 1),
                                     \ 'col'   : col,
                                     \ })
endfu
