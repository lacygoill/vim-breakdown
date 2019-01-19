" Interface {{{1
fu! breakdown#mark() abort "{{{2
    " `w:bd_marks` may need to be initialized.
    " And if a match is already present, it needs to be removed.
    call s:mark_init()
    call s:update_coords()

    " build a pattern using the coordinates in `w:bd_marks.coords`
    let w:bd_marks.pat = map(deepcopy(w:bd_marks.coords), { i,v -> '%'. v.line .'l%'. v.col .'v.' })
    let w:bd_marks.pat = '\v'.join(w:bd_marks.pat, '|')
    " When do we need to use `deepcopy()` instead of `copy()` ?{{{
    "
    " Every time we need to make a copy of the coordinates, we have to use
    " `deepcopy()`. We can't use `copy()`, because each item in the list of
    " coordinates is a dictionary, not just a simple data structure such as
    " a number or a string.
    "
    " `copy()` would create a new list of coordinates, but whose items would
    " share the same references as the ones in the original list.
    "
    " So, changing an item in the copy would immediately affect the original list.
    "}}}
    " Do we need `deepcopy()` here?{{{
    "
    " Here, probably not. But later, yes.
    "
    " Here,  we  don't change  any  key  of  the  dictionaries inside  the  list
    " `w:bd_marks.coords`. We simply use each dictionary to build a string which
    " populates a list (the one returned by `map()`).
    "
    " Later, we  may update the 'line'  key of each dictionary  (happens when we
    " expand the diagram above).
    "}}}
    " Why using `deepcopy()` here?{{{
    "
    "     1. better be safe than sorry
    "     2. consistency (`deepcopy()` later → `deepcopy()` now)
    "}}}

    " create a match and store its id in `w:bd_marks.id`
    let w:bd_marks.id = !empty(w:bd_marks.coords)
                    \ ?     matchadd('SpellBad', w:bd_marks.pat)
                    \ :     0
endfu

fu! breakdown#expand(shape, dir) abort "{{{2
    " don't try to draw anything if we don't have any coordinates
    if !exists('w:bd_marks.coords')
        return
    endif

    let [dir, shape] = [a:dir is# 'above' ? -1 : 0, a:shape]
    " we save the coordinates, because we may update them during the expansion
    " it happens when the diagram must be drawn above (not below)
    let coords_save = deepcopy(w:bd_marks.coords)

    " if we  want to draw  the diagram in which  the items contain  buckets, the
    " number of marked characters must be even, not odd
    if a:shape is# 'bucket' && len(w:bd_marks.coords) % 2 ==# 1
        echohl ErrorMsg
        echo '[breakdown] number of marked characters must be even'
        echohl None
        return
    endif

    " make sure 've' allows us to draw freely
    " also, make sure 'tw' and 'wm' don't break a long line
    let [ve_save, tw_save, wm_save] = [&ve, &l:tw, &l:wm]
    setl ve=all tw=0 wm=0

    " initialize empty location list
    let w:bd_marks.loclist = []

    " we sort the coordinates according to their column number, because
    " there's no guarantee that we marked the characters in order from left to
    " right
    call sort(w:bd_marks.coords, {x,y -> x.col - y.col})

    " In a  diagram containing  buckets, every  2 consecutive  marked characters
    " stand for one branch of the latter.
    " Therefore, the `for` loop which will progressively draw the diagram must
    " iterate over half of the coordinates.

    let coords_to_process = a:shape is# 'bucket'
                        \ ?     filter(deepcopy(w:bd_marks.coords), {i,v -> i%2 ==# 0})
                        \ :     deepcopy(w:bd_marks.coords)
    "                           │
    "                           └── why `deepcopy()`?{{{
    "
    " Because   we   may   update    the   line   coordinates,   later,   inside
    " `coords_to_process` (necessary if the diagram is drawn above).
    " And   if   we   do,   without   `deepcopy()`,   it   would   also   affect
    " `w:bd_marks.coords` because they would be the same list:
    "
    "         echo w:bd_marks.coords is coords_to_process
    "         1~
    "
    " Without `deepcopy()`, we would need to remove `coords_to_process` from the
    " next `for` loop:
    "
    "         for coord in coords_to_process + w:bd_marks.coords
    "         →
    "         for coord in w:bd_marks.coords
    "
    " To avoid that the elements are incremented twice, instead of once.
    "
    " But even then, the plugin wouldn't work as expected, because when we would
    " try to draw a bucket diagram above a line, it would be too high.
    "}}}


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

    " if there's a  commentstring, comment the diagram lines  (left side) except
    " in  a markdown  buffer, because  a diagram  won't cause  errors there,  so
    " there's no need to
    if !empty(&l:cms) && index(['markdown', 'text'], &ft) ==# -1
        let [cms_left, cms_right] = split(&l:cms, '%s', 1)
        call s:comment(cms_left, 'left', dir, hm_to_draw)
    endif

    for coord in coords_to_process
        " draw a branch of the diagram
        call s:draw(a:shape is# 'bucket', dir, coord, hm_to_draw)

        " populate the location list
        call s:populate_loclist(a:shape is# 'bucket', coord, dir, hm_to_draw)

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
        "                                       └ can't use `hm_to_draw` again
        "                                         because the variable has been decremented
        "                                         in the previous for loop
    endif

    " restore the  coordinates in  case we  changed the  addresses of  the lines
    " during the  expansion; this restoration  allows us to  re-expand correctly
    " the diagram later (after an undo), if we hit the wrong mapping by accident
    let w:bd_marks.coords = coords_save

    " restore the original values of the options we changed
    let [&ve, &l:tw, &l:wm] = [ve_save, tw_save, wm_save]

    call breakdown#clear_match()
    sil! call lg#motion#repeatable#make#set_last_used(']l', {'bwd': ',', 'fwd': ';'})
endfu

fu! breakdown#clear_match() abort "{{{2
    if exists('w:bd_marks.id')
        call matchdelete(w:bd_marks.id)
        " Why not removing `w:bd_marks` entirely?{{{
        "
        " At the end of `expand()`, we invoke this function to clear the match.
        " So, if we remove `w:bd_marks` here,  we won't be able to re-expand the
        " diagram without marking the characters again.
        "
        " IOW, the saved coordinates may still be useful; keep them.
        "}}}
        call remove(w:bd_marks, 'id')
    endif
endfu

fu! breakdown#put_error_sign(type) abort "{{{2
    let error_sign = '✘'
    let pointer = s:put_error_sign_location is# 'above'
        \ ? 'v'
        \ : '^'
    let vcol = virtcol('.')
    let cml = &ft is# 'markdown' ? '' : matchstr(get(split(&l:cms, '%s'), 0, ''), '\S*')
    let next_line = getline(line('.') + (s:put_error_sign_location is# 'above' ? -2 : 2))

    if next_line =~# error_sign
        " if our cursor is on the 20th cell, while the next lines occupy only 10
        " cells  the next  substitutions will  fail,  because it  will target  a
        " non-existing character
        let next_line_length = strchars(next_line, 1)
        if vcol > next_line_length
            let next_line .= repeat(' ', vcol - next_line_length)
        endif

        let pat = '\%'.vcol.'v'.repeat('.', strchars(error_sign, 1))
        let new_line = substitute(next_line, pat, error_sign, '')

        if s:put_error_sign_location is# 'above'
            --,-d_
        else
            +,++d_
            -
        endif
    else
        let indent = indent('.')
        let spaces_between_cml_and_mark = repeat(' ', virtcol('.')-1-strchars(cml, 1)-indent)
        let indent = repeat(' ', indent)
        let new_line = indent . cml . spaces_between_cml_and_mark . error_sign
    endif

    if s:put_error_sign_location is# 'above'
        let here = line('.')-1
        call append(here, new_line)
        call append(here+1, substitute(new_line, error_sign, pointer, 'g'))
        " Why this motion?{{{
        "
        " Without, `.` will move the cursor at the beginning of the line,
        " probably because of the previous `:delete` command.
        "}}}
        exe 'norm! '.vcol.'|'
        " Alternatively:{{{
        "
        " You could also have executed one of these right after the deletion:
        "
        "     --,-d_
        "     +-
        "
        "     --,-d_
        "     -+
        "
        "     --,-d_
        "     -
        "     +
        "
        "     --,-d_
        "     +
        "     -
        "
        " It would have prevented the cursor from jumping to the beginning of
        " the line when pressing `.`.
        "
        " Question: How does it work?
        "
        " MWE:
        "
        "     set nosol
        "     nno  <silent>  cd  :<c-u>set opfunc=Func<cr>g@l
        "     fu! Func(type) abort
        "         --,-d_
        "         call append(line('.')-1, '    " the date is:')
        "         call append(line('.')-1, '    " '.strftime('%c'))
        "         " the date is:
        "         " Wed 26 Sep 2018 12:58:35 AM CEST
        "         " foo bar baz qux norf
        "     endfu
        "
        " Source the code, move your cursor on the `foo bar ...` line,
        " and press `cd`.
        " Again, you can fix the issue by adding `+-` right after `:d`.
        "
        " Answer: from `:h 'sol`
        "
        "     ... When off the cursor is kept in the same column (if possible).
        "     This applies to the commands: ...
        "     Also for an Ex command that only has a line number, e.g., ":25" or ":+".
        "     In case  of BUFFER CHANGING  COMMANDS the  cursor is placed  at the
        "     column where it was the last time the buffer was edited.
        "
        " TODO:
        " Question:
        " Ok, `+-` doesn't make the column of the cursor change.
        " But it doesn't matter, the column of the cursor has ALREADY changed
        " when `:d` is executed!
        "
        " Besides, if you execute the 4 commands manually (:d, +-, append() x 2),
        " the issue is not fixed anymore.
        "
        " So why does `+-` work differently  depending on whether it's inside an
        " operator function, or outside?
        "}}}
    else
        let here = line('.')
        call append(here, substitute(new_line, error_sign, pointer, 'g'))
        call append(here+1, new_line)
        exe 'norm! '.vcol.'|'
    endif
endfu

fu! breakdown#put_v(dir) abort "{{{2
    if line("'<") != line("'>")
        return
    endif
    let line = substitute(getline('.'), '.', ' ', 'g')
    let col1 = min([virtcol("'<"), virtcol("'>")])
    let col2 = max([virtcol("'<"), virtcol("'>")])
    " Describes all the characters which were visually selected.{{{
    "
    " The pattern contains 3 branches because such a character could be:
    "
    "       • after the mark '< and before the mark '>
    "       • on the mark '<
    "       • on the mark '>
    "}}}
    let pat = '\%>'.col1.'v\%<'.col2.'v.\|\%'.col1.'v.\|\%'.col2.'v.'
    let line = substitute(line, pat, a:dir is# 'below' ? '^' : 'v', 'g')
    let line = substitute(line, '\s*$', '', '')
    if &l:cms isnot# '' && &ft isnot# 'markdown'
        let [cml_start, cml_end] = split(&l:cms, '%s', 1)
        let indent = indent('.')
        let line = repeat(' ', indent)
            \ . cml_start
            \ . line[strlen(cml_start) + indent :]
            \ . (!empty(cml_end) ? ' ' : '').cml_end
        " if  there are  already  marks on  the line  below/above,  don't add  a
        " new  line  with `append()`,  instead  replace  the current  line  with
        " `setline()`, merging its existing marks with the new ones
        let offset = (a:dir is# 'below' ? 1 : -1)
        let existing_line = getline(line('.') + offset)
        if existing_line =~# '^\s*\V'.escape(cml_start, '\').'\m[ v^]*$'
            let line = s:merge_lines(line, existing_line)
            call setline(line('.') + offset, line)
            return
        endif
    endif
    call append(a:dir is# 'below' ? '.' : line('.')-1, line)
endfu
" }}}1
" Core {{{1
fu! s:draw(is_bucket, dir, coord, hm_to_draw) abort "{{{2
    " This function draws a branch of the diagram.

    " reposition cursor before drawing the next branch
    exe 'norm! '. a:coord.line .'G'. a:coord.col . '|'

    if a:is_bucket
        call s:draw_bucket(a:dir, a:hm_to_draw, a:coord)
    else
        call s:draw_non_bucket(a:dir, a:hm_to_draw)
    endif
endfu

fu! s:draw_bucket(dir, hm_to_draw, coord) abort "{{{2
    let [dir, hm_to_draw, coord]  = [a:dir, a:hm_to_draw, a:coord]

    " get the index of the current marked character inside the list of
    " coordinates (w:bd_marks.coords)
    let i = index(w:bd_marks.coords, coord)
    " get the width of the `───` segment to draw above the item to describe
    let w = w:bd_marks.coords[i+1].col - coord.col - 1

    if dir ==# -1
        " draw `├───┐`
        exe 'norm! kR├'.repeat('─', w).'┐'
        exe 'norm! '.(w+1).'h'
        " draw the `│` column
        for i in range(1, hm_to_draw - 1)
            norm! kr│
        endfor
        " draw `┌`
        exe 'norm! kR┌ '

    else
        " draw `├───┘`
        exe 'norm! jR├'.repeat('─', w).'┘'
        exe 'norm! '.(w+1).'h'
        " draw the `│` column
        for i in range(1, hm_to_draw - 1)
            norm! jr│
        endfor
        " draw `└`
        exe 'norm! jR└ '
    endif
endfu

fu! s:draw_non_bucket(dir, hm_to_draw) abort "{{{2
    let [dir, hm_to_draw]  = [a:dir, a:hm_to_draw]

    if dir ==# -1
        " draw the `│` column
        for i in range(1, hm_to_draw + 1)
            norm! kr│
        endfor
        exe 'norm! R┌ '
    else
        " draw the `│` column
        for i in range(1, hm_to_draw + 1)
            exe 'norm! jr│'
        endfor
        exe 'norm! R└ '
    endif
endfu

fu! s:comment(what, where, dir, hm_to_draw) abort "{{{2
    " Purpose:{{{
    " This function is called once or twice per line of the diagram.
    " Twice if we're in a buffer whose commentstring has 2 parts.
    "
    " Example:    <!-- html text -->
    "             ^              ^
    "             first part     2nd part
    "
    " Its purpose is to comment each line of the diagram.
    " `what` is either the lhs or the rhs of a commentstring.
    "}}}

    " Before beginning commenting the lines of the diagram, make sure the cursor
    " is on the line we're describing.
    exe 'norm! '. w:bd_marks.coords[0].line .'G'

    let indent = repeat(' ', indent('.'))

    " iterate over the lines of the diagram
    for i in range(0, a:hm_to_draw)
        " move the cursor in the right direction
        exe (a:dir ==# -1 ? '-' : '+')

        let rep = a:where is# 'left'
              \ ?     indent . a:what
              \ :     substitute(getline('.'), '$', ' '.a:what, '')

        call setline('.', rep)
    endfor
endfu

fu! s:merge_lines(line, existing_line) abort "{{{2
    let [longest, shortest] = strlen(a:line) > strlen(a:existing_line)
        \ ? [a:line, a:existing_line]
        \ : [a:existing_line, a:line]
    let i = 0
    let longest = split(longest, '\zs')
    for char in split(shortest, '\zs')
        if char is# '^'
            let longest[i] = '^'
        elseif char is# 'v'
            let longest[i] = 'v'
        endif
        let i += 1
    endfor
    return join(longest, '')
endfu

fu! s:populate_loclist(is_bucket, coord, dir, hm_to_draw) abort "{{{2
    let [is_bucket, coord, dir, hm_to_draw] = [a:is_bucket, a:coord, a:dir, a:hm_to_draw]

    " Example of bucket diagram:{{{
    "
    "     search('=\%#>', 'bn', line('.'))
    "            ├─────┘  ├──┘  ├───────┘
    "            │        │     └ search in the current line only
    "            │        │
    "            │        └ backwards without moving the cursor and
    "            │
    "            └ match any `=[>]`, where `[]` denotes the
    "              cursor's position
    "}}}
    " NOTE:{{{
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
    "
"}}}
        if is_bucket
            " We are going to store the byte index of the character where we
            " want the cursor to be positioned.
            " To compute this byte index, we first need to know the index of the
            " first of  the 2 marked characters  from which we draw  a branch of
            " the diagram; the one above/below `└`/`┌`.

            let i = index(w:bd_marks.coords, coord)

            let col = w:bd_marks.coords[i].col + (len(w:bd_marks.coords)/2 - hm_to_draw)*2 + 4
            "         │                          │
            "         │                          └ before `[└┌]`, there could be some `│`:
            "         │                            add 2 bytes for each of them
            "         │
            "         └ byte index of the next marked character (the one above/below `[┤├]`)
            " NOTE:
            " The weight of our multibyte characters is 3, so why do we add only 2 bytes for each of them?
            " Because with `coord.col`, we already added one byte for each of them.
        else
            let col = coord.col + 2*(len(w:bd_marks.coords) - hm_to_draw) + (1*2)+1
            "         │           │                                          │
            "         │           │                                          └ add 3 as a fixed offset
            "         │           │
            "         │           └ before `└`, there could be some `│`:
            "         │             add 2 bytes for each of them
            "         │
            "         └ number of bytes up to `└`/marked character
        endif

        call add(w:bd_marks.loclist, {
        \            'bufnr' : bufnr('%'),
        \            'lnum'  : coord.line + (dir ==# -1 ? -hm_to_draw - 1 : hm_to_draw + 1),
        \            'col'   : col,
        \ })
endfu
" }}}1
" Misc. {{{1
fu! s:mark_init() abort "{{{2
    if !exists('w:bd_marks.id')
        let w:bd_marks = {
        \       'coords' : [],
        \       'pat'    : '',
        \       'id'     :  0,
        \ }
    elseif w:bd_marks.id
        " if there's a match, delete it because we're going to update it:
        " we don't want to add a new match besides the old one
        call matchdelete(w:bd_marks.id)
        " and add a bar at the end of the pattern, to prepare for the new branch
        let w:bd_marks.pat .= '|'
    endif
endfu

fu! breakdown#put_error_sign_where(dir) abort "{{{2
    let s:put_error_sign_location = a:dir
endfu

fu! s:update_coords() abort "{{{2
    " If we're on the same line as the previous marked characters…
    if !empty(w:bd_marks.coords) && line('.') ==# w:bd_marks.coords[0].line

        " … and if the current position is already marked, then instead of
        " re-adding it as a mark, remove it (toggle).
        if index( w:bd_marks.coords,
            \ {'line' : line('.'), 'col' : virtcol('.')})
            \  >= 0

            call filter(w:bd_marks.coords,
                \ {i,v ->  v !=# {'line' : line('.'), 'col' : virtcol('.')}}
                \ )
        else

            " … otherwise, add the current position to the list of coordinates

            let w:bd_marks.coords += [{
            \       'line' : line('.'),
            \       'col'  : virtcol('.'),
            \ }]
        endif

    else
    " Otherwise, if we're marking a character on a different line, reset
    " completely the list of coordinates.

        let w:bd_marks.coords = [{
        \       'line' : line('.'),
        \       'col'  : virtcol('.'),
        \ }]
    endif
endfu

