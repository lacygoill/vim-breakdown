let s:save_cpo = &cpo
set cpo&vim

" ―――――――――――――――― clear "{{{

fu! breakdown#clear() abort
    if exists('w:bd_marks')
        call matchdelete(w:bd_marks.id)
        unlet w:bd_marks
    endif
endfu

"}}}
" ―――――――――――――――― comment "{{{

fu! s:comment(what, where, dir) abort
    let nr_lines = len(w:bd_marks.coords)

    exe 'norm! '. w:bd_marks.coords[0].line .'G'

    for j in range(0, nr_lines)
        exe (a:dir == -1 ? '-' : '+')

        let replacement = a:where ==# 'right'
                        \   ? substitute(getline('.'), '$', ' '.a:what, '')
                        \   : a:what
        call setline(line('.'), replacement)
    endfor
endfu

"}}}
" ―――――――――――――――― draw "{{{

<<<<<<< HEAD
" This function draws a piece of the diagram.
fu! breakdown#draw(align, dir, coord, hm_to_draw)
    let [ align, dir, coord, hm_to_draw ] = [ a:align, a:dir, a:coord, a:hm_to_draw ]

    let characters = extend(
                   \         get(
                   \              b:,
                   \              'breakdown_characters',
                   \              get(g:, 'breakdown#characters', {})
                   \            ),
                   \
                   \         {
                   \            'hor'        : '─',
                   \            'vert'       : '│',
                   \            'down_right' : '┌',
                   \            'vert_left'  : '┤',
                   \            'up_right'   : '└',
                   \          },
                   \
                   \         'keep'
                   \       )

    let hor        = characters.hor
    let vert       = characters.vert
    let down_right = characters.down_right
    let vert_left  = characters.vert_left
    let up_right   = characters.up_right

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

        if dir == -1
            " draw `┌───┤`
            exe 'norm! kR'.down_right.repeat(hor, w).vert_left
            " draw the `│` column
            for i in range(1, hm_to_draw - 1)
                exe 'norm! kr'.vert
            endfor
            " draw `┌────`
            exe 'norm! kR'.down_right.repeat(hor, ww)

        else
            " draw `└───┤`
            exe 'norm! jR'.up_right.repeat(hor, w).vert_left
            " draw the `│` column
            for i in range(1, hm_to_draw - 1)
                exe 'norm! jr'.vert
            endfor
            " draw `└────`
            exe 'norm! jR'.up_right.repeat(hor, ww).' '
        endif

    else
        if dir == -1
            " draw the `│` column
            for i in range(1, hm_to_draw + 1)
                exe 'norm! kr'.vert
            endfor
            exe 'norm! R'.down_right.hor.' '
        else
            " draw the `│` column
            for i in range(1, hm_to_draw + 1)
                exe 'norm! jr'.vert
            endfor
            exe 'norm! R'.up_right.hor.' '
        endif
    endif
endfu

"}}}
" ―――――――――――――――― main "{{{

fu! s:sort(x,y) abort
    return a:x.col - a:y.col
endfu

fu! breakdown#main(dir, align) abort
=======
fu! breakdown#draw(dir, align) abort
>>>>>>> parent of 248e2e4... add support for aligned diagram
    " don't try to draw anything if we don't have any coordinates
    if !exists('w:bd_marks.coords')
        return
    endif

    " make sure 've' allows us to draw freely
    " also, make sure 'tw' and 'wm' don't break a long line
    let [ve_save, tw_save, wm_save] = [&ve, &l:tw, &l:wm]
    setl ve=all tw=0 wm=0

<<<<<<< HEAD
    " initialize empty location list
    let w:bd_marks.loclist = []

    " we sort the coordinates according to their column number, because
    " there's no guarantee that we marked the characters in order from left to
    " right
    " NOTE:
    " we could remove the `breakdown#sort()` function and replace it with
    " a lambda expression:
    "     call sort(w:bd_marks.coords, { x,y -> x.col - y.col })
    call sort(w:bd_marks.coords, 's:sort')

    " In a diagram in which the descriptions are aligned, every 2 consecutive
    " marked characters stand for one piece of the latter.
    " Therefore, the `for` loop which will progressively draw the diagram must
    " iterate over half of the coordinates.

    let coords_to_process = align
                          \   ? filter(deepcopy(w:bd_marks.coords), 'v:key % 2 == 0')
                          \   : deepcopy(w:bd_marks.coords)
"                               │
"                               └── why `deepcopy()`?
"                               because we may update the line coordinates, later, inside `coords_to_process`
"                               (if we open some lines above)
"                               and if we do, without `deepcopy()`, it would also affect `w:bd_marks.coords`
"                               because they would be the same list:
"
"                                       echo w:bd_marks.coords is coords_to_process    →    1
"
"                               without this separation, we would need to remove `coords_to_process` from
"                               the next `for` loop:
"
"                                       for coord in coords_to_process + w:bd_marks.coords
"                                       →
"                                       for coord in w:bd_marks.coords
"
"                               … to avoid that the elements are incremented twice, instead of once
"
"                               but even then, the plugin wouldn't work as expected,
"                               because when we would try to draw an aligned diagram above a line,
"                               it would be too high


    " How Many lines of the diagram are still TO be DRAWn
    let hm_to_draw = len(coords_to_process)
=======
    let coords   = w:bd_marks.coords
    let nr_lines = len(coords)
>>>>>>> parent of 248e2e4... add support for aligned diagram

    " make sure the cursor is on the line containing marked characters
    exe 'norm! '.coords[0].line.'G'

    " open enough new lines to draw diagram
    call append(line('.') + a:dir, repeat([''], nr_lines + 1))

    " if we open lines above, the addresses of the lines must be
    " updated, incremented with `nr_lines + 1`
    if a:dir == -1
        for coord in w:bd_marks.coords
            let coord.line = coord.line + nr_lines + 1
        endfor
    endif

    " if there's a commentstring, comment the diagram lines (left side)
    " except in a markdown buffer, because a diagram won't cause errors in
    " a note file, so there's no need to
    if !empty(&cms) && &ft !=# 'markdown'
        let [cms_left, cms_right] = split(&cms, '%s', 1)
        call s:comment(cms_left, 'left', a:dir)
    endif

    let loclist = []
    " we sort the coordinates according to their column number, because
    " there's no guarantee that we marked the characters in order from left to
    " right

<<<<<<< HEAD
        " populate the location list
        call s:populate_loclist(align, coord, dir, hm_to_draw)
=======
    for i in sort(coords, {x,y -> x.col - y.col})
        " position cursor before drawing
        if a:dir == -1
            exe 'norm! '. (i.line - nr_lines - 1) .'G'
        else
            exe 'norm! '. i.line .'Gj'
        endif
        exe 'norm! '. i.col . '|'
>>>>>>> parent of 248e2e4... add support for aligned diagram

        " draw a branch of the diagram
        if a:dir == -1
            exe 'norm! R┌── '
            norm! 3h
            for j in range(1, nr_lines)
                norm! jr│
            endfor
        else
            for j in range(1, nr_lines)
                norm! r│j
            endfor
            exe 'norm! R└── '
        endif

        " build location list data
        "
        " We add:
        "
        "     (4 + (len(coords) - nr_lines + 1))*2
        "
        " … to the value of the key `col`, because every time we move up in
        " the diagram, there's one more branch before the text we're going to
        " write:
        "         len(coords) - nr_lines + 1
        "
        " … to be precise.
        "
        " For every branch before us, we must move our cursor one character to
        " the right. And we must multiply the result by 2, because we're using
        " multibyte characters.
        call add(loclist, {
                          \ 'bufnr' : bufnr('%'),
                          \ 'lnum'  : i.line + (a:dir == -1 ? -nr_lines - 1 : nr_lines + 1),
                          \ 'col'   : i.col + (4 + (len(coords) - nr_lines + 1))*2,
                          \ })
        let nr_lines -= 1
    endfor

    " if there's a commentstring, and has a non empty right part,
    " comment the right side of the diagram lines
    if exists('cms_right') && !empty(cms_right)
        call s:comment(cms_right, 'right', a:dir)
    endif

<<<<<<< HEAD
    if exists('#User#BreakdownPost')
        doautocmd <nomodeline> User BreakdownPost
    endif
=======
    " set location list
    call setloclist(0, loclist)

    " make the motion in the location list repeatable with `;` and `,`
    sil! norm ]l[l
    " position cursor on first entry
    lfirst
>>>>>>> parent of 248e2e4... add support for aligned diagram

    " clear match
    call breakdown#clear()

    let [&ve, &l:tw, &l:wm] = [ve_save, tw_save, wm_save]
endfu

"}}}
" ―――――――――――――――― mark "{{{

fu! breakdown#mark() abort
    " if `w:bd_marks` doesn't exist, initialize it
    if !exists('w:bd_marks')
        let w:bd_marks = {
                         \ 'coords'  : [],
                         \ 'pattern' : '',
                         \ 'id'      :  0,
                         \ }
    else
        if w:bd_marks.id
            " otherwise if it exists and `w:bd_marks.id` is != 0,
            " delete the match because we're going to update it:
            " we don't want to add a new match besides the old one
            call matchdelete(w:bd_marks.id)
            " and add a bar at the end of the pattern, to prepare for a new
            " branch
            let w:bd_marks.pattern .= '|'
        endif
    endif

    " If we're on the same line as the previous marked characters…
    if !empty(w:bd_marks.coords) && line('.') == w:bd_marks.coords[0].line

        " … and if the current position is already marked, then instead of
        " readding it as a mark, remove it (toggle).
        if count(w:bd_marks.coords, {'line' : line('.'), 'col' : virtcol('.')} )

            call filter(w:bd_marks.coords, " v:val != {'line' : line('.'), 'col' : virtcol('.')} ")
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

        let w:bd_marks.coords  = [{
                                  \ 'line' : line('.'),
                                  \ 'col'  : virtcol('.'),
                                  \ }]
    endif

    " build a pattern using the coordinates in `w:bd_marks.coords`
    let w:bd_marks.pattern = '\v'
                           \ .join(
                           \       map(
                           \           deepcopy(w:bd_marks.coords),
                           \           "'%'.v:val.line.'l%'.v:val.col.'v.'"
                           \          ),
                           \       '|'
                           \      )

    " create a match and store its id in `w:bd_marks.id`
    let w:bd_marks.id = !empty(w:bd_marks.coords)
                        \   ? matchadd('SpellBad', w:bd_marks.pattern)
                        \   : 0
endfu

"}}}
<<<<<<< HEAD
" ―――――――――――――――― populate_loclist "{{{

fu! s:populate_loclist(align, coord, dir, hm_to_draw) abort
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
            let col  = w:bd_marks.coords[i+1].col + ((len(w:bd_marks.coords)/2 - hm_to_draw))*multiplier
"                      │                            │
"                      │                            └── before `└`/`┌`, there could be some `│`:
"                      │                                add 2 bytes for each of them
"                      │
"                      └── byte index of the next marked character (the one above/below `┤`)
"           NOTE:
"           The weight of our multibyte characters is 3, so why do we add only 2 bytes for each of them?
"           Because with `coord.col`, we already added one byte for each of them.

            let col += 3*(w:bd_marks.coords[-1].col - w:bd_marks.coords[i+1].col) + (3*1) + 1
"                      │                                                            │
"                      │                                                            └── add 4 as a fixed offset
"                      │                                                                1 drawing character + 1 space
"                      └── add 3 bytes for every character in the `└──…` segment
        else
            let col  = coord.col + 2*((len(w:bd_marks.coords) - hm_to_draw)) + (3*2)+1
"                      │           │                                           │
"                      │           │                                           └── add 7 as a fixed offset
"                      │           │                                               2 drawing characters + 1 space
"                      │           └── before `└`, there could be some `│`: add 2 bytes for each of them
"                      └── number of bytes up to `└`/marked character
        endif

        call add(w:bd_marks.loclist, {
                                     \ 'bufnr' : bufnr('%'),
                                     \ 'lnum'  : coord.line + (dir == -1 ? -hm_to_draw - 1 : hm_to_draw + 1),
                                     \ 'col'   : col,
                                     \ })
endfu

"}}}

let &cpo = s:save_cpo
=======

>>>>>>> parent of 248e2e4... add support for aligned diagram
