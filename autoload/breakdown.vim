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

fu! breakdown#draw(dir) abort
    " don't try to draw anything if we don't have any coordinates
    if !exists('w:bd_marks.coords')
        return
    endif

    " make sure 've' allows us to draw freely
    " also, make sure 'tw' and 'wm' don't break a long line
    let [ve_save, tw_save, wm_save] = [&ve, &l:tw, &l:wm]
    setl ve=all tw=0 wm=0

    let coords   = w:bd_marks.coords
    let nr_lines = len(coords)

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

    for i in sort(coords, {x,y -> x.col - y.col})
        " position cursor before drawing
        if a:dir == -1
            exe 'norm! '. (i.line - nr_lines - 1) .'G'
        else
            exe 'norm! '. i.line .'Gj'
        endif
        exe 'norm! '. i.col . '|'

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
        " the diagram, there's one branch more before the text we're going to
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

    " set location list
    call setloclist(0, loclist)

    " make the motion in the location list repeatable with `;` and `,`
    sil! norm ]l[l
    " position cursor on first entry
    lfirst

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

