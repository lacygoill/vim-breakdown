vim9script noclear

if exists('loaded') | finish | endif
var loaded = true

import IsVim9 from 'lg.vim'

# Interface {{{1
def breakdown#mark() #{{{2
    # `w:bd_marks` may need to be initialized.
    # And if a match is already present, it needs to be removed.
    MarkInit()
    UpdateCoords()

    # build a pattern using the coordinates in `w:bd_marks.coords`
    w:bd_marks.pat = w:bd_marks.coords
        ->mapnew((_, v: dict<number>): string =>
            '\%' .. v.line .. 'l\%' .. v.col .. 'v.')
        ->join('\|')

    # create a match and store its id in `w:bd_marks.id`
    w:bd_marks.id = !empty(w:bd_marks.coords)
        ? matchadd('SpellBad', w:bd_marks.pat, 0)
        : 0
enddef

def breakdown#expand(arg_shape: string, arg_dir: string) #{{{2
    # don't try to draw anything if we don't have any coordinates
    if !exists('w:bd_marks.coords')
        return
    endif

    var dir: number = arg_dir == 'above' ? -1 : 0
    var shape: string = arg_shape
    # we save the coordinates, because we may update them during the expansion
    # it happens when the diagram must be drawn above (not below)
    var coords_save: list<dict<number>> = deepcopy(w:bd_marks.coords)

    if arg_shape == 'bucket' && len(w:bd_marks.coords) % 2 == 1
        echohl ErrorMsg
        echo '[breakdown] number of marked characters must be even'
        echohl None
        return
    endif

    # make sure that:{{{
    #
    #    - `'ve'` lets us draw freely
    #    - `'tw'` and `'wm'` don't break a long line
    #    - `'fdm'` doesn't make the edition slow in the middle of a big folded file
    #}}}
    var opts_save: dict<any> = {
        ve: &ve,
        tw: &l:tw,
        wm: &l:wm,
        fdm: &l:fdm,
        bufnr: bufnr('%'),
        }
    set ve=all
    setl tw=0 wm=0 fdm=manual

    # we sort the coordinates according  to their column number, because there's
    # no guarantee that we marked the characters in order from left to right
    w:bd_marks.coords
        ->sort((x: dict<number>, y: dict<number>): number => x.col - y.col)

    # In a  diagram containing  buckets, every  2 consecutive  marked characters
    # stand for one branch of the latter.
    # Therefore, the `for`  loop which will progressively draw  the diagram must
    # iterate over half of the coordinates.
    # Why `deepcopy()`?{{{
    #
    # Because   we   may   update    the   line   coordinates,   later,   inside
    # `coords_to_process` (necessary if the diagram is drawn above).
    # And   if   we   do,   without   `deepcopy()`,   it   would   also   affect
    # `w:bd_marks.coords` because they would be the same list:
    #
    #     echo w:bd_marks.coords is coords_to_process
    #     1~
    #
    # Without `deepcopy()`, we would need to remove `coords_to_process` from the
    # next `for` loop:
    #
    #     for coord in coords_to_process + w:bd_marks.coords
    #     →
    #     for coord in w:bd_marks.coords
    #
    # To avoid that the elements are incremented twice, instead of once.
    #
    # But even then, the plugin wouldn't work as expected, because when we would
    # try to draw a bucket diagram above a line, it would be too high.
    #}}}
    var coords_to_process: list<dict<number>> = deepcopy(w:bd_marks.coords)
    if arg_shape == 'bucket'
        coords_to_process->filter((i: number): bool => i % 2 == 0)
    endif

    # How Many lines of the diagram are still TO be DRAWn
    var hm_to_draw: number = len(coords_to_process)

    # make sure the cursor is on the line containing marked characters
    exe 'norm! ' .. w:bd_marks.coords[0]['line'] .. 'G'

    # open enough new lines to draw diagram
    repeat([''], hm_to_draw + 1)->append(line('.') + dir)

    # if we've just opened new lines above (instead of below) ...
    if dir == -1
        # ... the address of the line of the marked characters must be updated
        for coord in coords_to_process + w:bd_marks.coords
        #                              │
        #                              └ `coords_to_process` is only a copy
        #                                of (a subset of) `w:bd_marks.coords`
        #                                we also need to update the original coordinates

            # ... increment it with `len(coords_to_process) + 1`
            coord.line = coord.line + len(coords_to_process) + 1
        endfor
    endif

    # if there's a  commentstring, comment the diagram lines  (left side) except
    # in  a markdown  buffer, because  a diagram  won't cause  errors there,  so
    # there's no need to
    if !empty(&l:cms) && index(['markdown', 'text'], &ft) == -1
        var cml_left: string
        var _: any
        [cml_left; _] = Getcml()
        Comment(cml_left, dir, hm_to_draw)
    endif

    # initialize empty location list
    w:bd_marks.loclist = []

    for coord in coords_to_process
        # draw a branch of the diagram
        Draw(arg_shape == 'bucket', dir, coord, hm_to_draw)

        # populate the location list
        PopulateLoclist(arg_shape == 'bucket', coord, dir, hm_to_draw)

        hm_to_draw -= 1
    endfor

    # set location list
    setloclist(0, [], ' ', {items: w:bd_marks.loclist, title: 'Breakdown'})

    # restore the  coordinates in  case we  changed the  addresses of  the lines
    # during the  expansion; this  restoration lets  us re-expand  correctly the
    # diagram later (after an undo), if we hit the wrong mapping by accident
    w:bd_marks.coords = coords_save

    # restore the original values of the options we changed
    &ve = opts_save.ve
    setbufvar(opts_save.bufnr, '&tw', opts_save.tw)
    setbufvar(opts_save.bufnr, '&wm', opts_save.wm)
    setbufvar(opts_save.bufnr, '&fdm', opts_save.fdm)

    breakdown#clearMatch()
enddef

def breakdown#clearMatch() #{{{2
    if exists('w:bd_marks.id')
        matchdelete(w:bd_marks.id)
        # Why not removing `w:bd_marks` entirely?{{{
        #
        # At the end of `expand()`, we invoke this function to clear the match.
        # So, if we remove `w:bd_marks` here,  we won't be able to re-expand the
        # diagram without marking the characters again.
        #
        # IOW, the saved coordinates may still be useful; keep them.
        #}}}
        remove(w:bd_marks, 'id')
    endif
enddef

def breakdown#putErrorSignSetup(where: string): string #{{{2
    put_error_sign_where = where
    &opfunc = expand('<SID>') .. 'PutErrorSign'
    return 'g@l'
enddef

var put_error_sign_where: string

def breakdown#putV(dir: string) #{{{2
    if line("'<") != line("'>")
        return
    endif
    # we need `strdisplaywidth()` in case the line contains multicell characters, like tabs
    var line: string = getline('.')
        ->substitute(
            '.',
            (m: list<string>): string =>
                ' '->repeat(strdisplaywidth(m[0], virtcol('.'))),
            'g')
    var col1: number = min([virtcol("'<"), virtcol("'>")])
    var col2: number = max([virtcol("'<"), virtcol("'>")])
    # Describes all the characters which were visually selected.{{{
    #
    # The pattern contains 3 branches because such a character could be:
    #
    #    - after the mark '< and before the mark '>
    #    - on the mark '<
    #    - on the mark '>
    #}}}
    var pat: string = '\%>' .. col1 .. 'v\%<' .. col2 .. 'v.'
        .. '\|\%' .. col1 .. 'v.\|\%' .. col2 .. 'v.'
    line = line
            ->substitute(pat, dir == 'below' ? '^' : 'v', 'g')
            ->substitute('\s*$', '', '')
    # `^---^` is nicer than `^^^^^`
    line = line
            ->substitute(
                '[v^]\zs.*\ze[v^]',
                (m: list<string>): string => repeat('-', len(m[0])),
                '')
    var cml_left: string
    var cml_right: string
    [cml_left, cml_right] = Getcml()
    var indent: number = indent('.')
    line = repeat(' ', indent)
        .. cml_left
        .. line[strchars(cml_left, true) + indent :]
        .. (!empty(cml_right) ? ' ' : '') .. cml_right
    # if  there are  already  marks on  the line  below/above,  don't add  a
    # new  line  with `append()`,  instead  replace  the current  line  with
    # `setline()`, merging its existing marks with the new ones
    var offset: number = (dir == 'below' ? 1 : -1)
    var existing_line: string = (line('.') + offset)->getline()
    if existing_line =~ '^\s*' .. '\V' .. escape(cml_left, '\') .. '\m' .. '[ v^-]*$'
        line = MergeLines(line, existing_line)
        setline(line('.') + offset, line)
        return
    endif
    append(dir == 'below' ? '.' : line('.') - 1, line)
enddef
# }}}1
# Core {{{1
def Draw(is_bucket: bool, dir: number, coord: dict<number>, hm_to_draw: number) #{{{2
    # This function draws a branch of the diagram.

    # reposition cursor before drawing the next branch
    exe 'norm! ' .. coord.line .. 'G' .. coord.col .. '|'

    if is_bucket
        DrawBucket(dir, hm_to_draw, coord)
    else
        DrawNonBucket(dir, hm_to_draw)
    endif
enddef

def DrawBucket(dir: number, hm_to_draw: number, coord: dict<number>) #{{{2
    # get the index of the current marked character inside the list of
    # coordinates (`w:bd_marks.coords`)
    var i: number = index(w:bd_marks.coords, coord)
    # get the width of the `───` segment to draw above the item to describe
    var w: number = w:bd_marks.coords[i + 1]['col'] - coord.col - 1

    if dir == -1
        # draw `├───┐`
        exe 'norm! kR├' .. repeat('─', w) .. '┐'
        exe 'norm! ' .. (w + 1) .. 'h'
        # draw the `│` column
        for ii in range(1, hm_to_draw - 1)
            norm! kr│
        endfor
        # draw `┌`
        exe 'norm! kR┌ '

    else
        # draw `├───┘`
        exe 'norm! jR├' .. repeat('─', w) .. '┘'
        exe 'norm! ' .. (w + 1) .. 'h'
        # draw the `│` column
        for ii in range(1, hm_to_draw - 1)
            norm! jr│
        endfor
        # draw `└`
        exe 'norm! jR└ '
    endif
enddef

def DrawNonBucket(dir: number, hm_to_draw: number) #{{{2
    if dir == -1
        # draw the `│` column
        for i in range(1, hm_to_draw + 1)
            norm! kr│
        endfor
        exe 'norm! R┌ '
    else
        # draw the `│` column
        for i in range(1, hm_to_draw + 1)
            norm! jr│
        endfor
        exe 'norm! R└ '
    endif
enddef

def Comment(what: string, dir: number, hm_to_draw: number) #{{{2
    # Purpose:{{{
    # This function is called once or twice per line of the diagram.
    # Twice if we're in a buffer whose commentstring has 2 parts.
    #
    # Example:    <!-- html text -->
    #             ^              ^
    #             first part     2nd part
    #
    # Its purpose is to comment each line of the diagram.
    # `what` is either the lhs or the rhs of a commentstring.
    #}}}

    # Before beginning commenting the lines of the diagram, make sure the cursor
    # is on the line we're describing.
    exe 'norm! ' .. w:bd_marks.coords[0]['line'] .. 'G'

    var indent: string = repeat(' ', indent('.'))

    # iterate over the lines of the diagram
    for i in range(0, hm_to_draw)
        # move the cursor in the right direction
        exe ':' .. (dir == -1 ? '-' : '+')

        var rep: string = indent .. what

        setline('.', rep)
    endfor
enddef

def MergeLines(line: string, existing_line: string): string #{{{2
    var longest: string
    var shortest: string
    if strchars(line, true) > strchars(existing_line, true)
        [longest, shortest] = [line, existing_line]
    else
        [longest, shortest] = [existing_line, line]
    endif
    var i: number = 0
    var chars_in_longest: list<string> = split(longest, '\zs')
    for char in split(shortest, '\zs')
        if char =~ '[v^-]'
            chars_in_longest[i] = char
        endif
        i += 1
    endfor
    return join(chars_in_longest, '')
enddef

def PopulateLoclist( #{{{2
    is_bucket: bool,
    coord: dict<number>,
    dir: number,
    hm_to_draw: number)

    # Example of bucket diagram:{{{
    #
    #     search('=\%#>', 'bn', line('.'))
    #            ├─────┘  ├──┘  ├───────┘
    #            │        │     └ search in the current line only
    #            │        │
    #            │        └ backwards without moving the cursor and
    #            │
    #            └ match any `=[>]`, where `[]` denotes the
    #              cursor's position
    #}}}
    # NOTE:{{{
    # When we stored the position of the marked characters, we've used `virtcol()`,
    # so `coord.col` is a visual column, not a byte index.
    # But we need the byte index of the beginning of a line in the diagram.
    #
    # If there are multibyte characters before a marked character, does it cause
    # an issue for the  byte index of the beginning of a line  in the diagram in
    # the location list?
    #
    # No.  Because before the beginning of a line in the diagram, there are only
    # spaces (and optionally comment characters).
    # And spaces  aren't multibyte.  So,  the byte index  of the beginning  of a
    # line in the diagram matches the  visual column of the corresponding marked
    # character.
    #}}}
    var col: number
    if is_bucket
        # We are going to store the byte index of the character where we
        # want the cursor to be positioned.
        # To compute this byte index, we first need to know the index of the
        # first of  the 2 marked characters  from which we draw  a branch of
        # the diagram; the one above/below `└`/`┌`.

        var i: number = index(w:bd_marks.coords, coord)

        col = w:bd_marks.coords[i]['col'] + (len(w:bd_marks.coords) / 2 - hm_to_draw) * 2 + 4
        #     │                             │
        #     │                             └ before `[└┌]`, there could be some `│`:
        #     │                               add 2 bytes for each of them
        #     │
        #     └ byte index of the next marked character (the one above/below `[┤├]`)
        # NOTE:
        # The weight of our multibyte characters is 3, so why do we add only 2 bytes for each of them?
        # Because with `coord.col`, we already added one byte for each of them.
    else
        col = coord.col + 2 * (len(w:bd_marks.coords) - hm_to_draw) + (1 * 2) + 1
        #     │           │                                            │
        #     │           │                                            └ add 3 as a fixed offset
        #     │           │
        #     │           └ before `└`, there could be some `│`:
        #     │             add 2 bytes for each of them
        #     │
        #     └ number of bytes up to `└`/marked character
    endif

    add(w:bd_marks.loclist, {
        bufnr: bufnr('%'),
        lnum: coord.line + (dir == -1 ? -hm_to_draw - 1 : hm_to_draw + 1),
        col: col,
        })
enddef

def PutErrorSign(_a: any) #{{{2
    var ballot: string = '✘'
    var checkmark: string = '✔'
    var pointer: string = put_error_sign_where == 'above'
        ? 'v'
        : '^'
    var vcol: number = virtcol('.')
    var cml: string
    var _: any
    [cml; _] = Getcml()
    var next_line: string = (line('.') + (put_error_sign_where == 'above' ? -2 : 2))
        ->getline()

    var new_line: string
    if next_line =~ ballot
        # if our cursor is on the 20th cell, while the next lines occupy only 10
        # cells the  next substitutions  will fail, because  they will  target a
        # non-existing character;  need to prevent  that by appending  spaces if
        # needed
        var next_line_length: number = strchars(next_line, true)
        if vcol > next_line_length
            next_line ..= repeat(' ', vcol - next_line_length)
        endif

        var pat: string = '\%' .. vcol .. 'v' .. repeat('.', strchars(ballot, true))
        new_line = next_line->substitute(pat, ballot, '')

        if put_error_sign_where == 'above'
            keepj :--,-d _
        else
            keepj :+,++d _
            :-
        endif
    else
        var indent_lvl: number = indent('.')
        var spaces_between_cml_and_mark: string = repeat(' ',
            virtcol('.') - 1 - strchars(cml, true) - indent_lvl)
        var indent: string = repeat(' ', indent_lvl)
        new_line = indent .. cml .. spaces_between_cml_and_mark .. ballot
    endif

    if put_error_sign_where == 'above'
        var here: number = line('.') - 1
        append(here, new_line)
        new_line
            ->substitute(ballot .. '\|' .. checkmark, pointer, 'g')
            ->append(here + 1)
    else
        var here: number = line('.')
        new_line
            ->substitute(ballot .. '\|' .. checkmark, pointer, 'g')
            ->append(here)
        append(here + 1, new_line)
    endif
    # Why this motion?{{{
    #
    # Without, `.` will  move the cursor at the beginning  of the line, probably
    # because of the previous `:delete` command.
    #}}}
    exe 'norm! ' .. vcol .. '|'
    # Alternatively:{{{
    #
    # You could also have executed one of these right after the deletion:
    #
    #     --,-d_
    #     +-
    #
    #     --,-d_
    #     -+
    #
    #     --,-d_
    #     -
    #     +
    #
    #     --,-d_
    #     +
    #     -
    #
    # It would have prevented the cursor from jumping to the beginning of
    # the line when pressing `.`.
    #
    # Question: How does it work?
    #
    # Answer: from `:h 'sol`
    #
    #    > ... When off the cursor is kept in the same column (if possible).
    #    > This applies to the commands: ...
    #    > Also for an Ex command that only has a line number, e.g., ":25" or ":+".
    #    > In case  of **buffer changing  commands** the  cursor is placed  at the
    #    > column where it was the last time the buffer was edited.
    #
    # MWE:
    #
    #     $ vim -Nu <(cat <<'EOF'
    #         set nosol
    #         nno cd <cmd>call Func()<cr>
    #         fu Func() abort
    #            --,-d_
    #            call append(line('.') - 1, 'the date is:')
    #            call strftime('%c')->append(line('.') - 1)
    #         endfu
    #     EOF
    #     ) +"put =['the date is:', 'today', 'some text']"
    #
    #     " press `e` to move the cursor on the 'e' of 'some'
    #     " press `cd`
    #     " the cursor has jumped onto the first character of the line
    #
    # Again, you can fix the issue by adding `+-` right after `:d`.
    #
    # TODO:
    #
    # Ok, `+-` doesn't make the column of the cursor change.
    # But it doesn't matter, the column  of the cursor has *already* changed
    # when `:d` is executed!
    #
    # Besides, if you execute the 4 commands manually (:d, +-, append() x 2),
    # the issue is not fixed anymore.
    #
    # So why does  `+-` work differently depending on whether  it's inside a
    # function, or outside?
    #}}}
enddef

def MarkInit() #{{{2
    if !exists('w:bd_marks.id')
        w:bd_marks = {
            coords: [],
            pat: '',
            id: 0,
            }
    elseif w:bd_marks.id != 0
        # if there's a match, delete it because we're going to update it:
        # we don't want to add a new match besides the old one
        matchdelete(w:bd_marks.id)
        # and add a bar at the end of the pattern, to prepare for the new branch
        w:bd_marks.pat = w:bd_marks.pat .. '\|'
    endif
enddef

def UpdateCoords() #{{{2
    # If we're on the same line as the previous marked characters...
    if !empty(w:bd_marks.coords) && line('.') == w:bd_marks.coords[0]['line']

        # ... and  if the current  position is  already marked, then  instead of
        # re-adding it as a mark, remove it (toggle).
        if index(w:bd_marks.coords, {line: line('.'), col: virtcol('.')}) >= 0
            w:bd_marks.coords
                ->filter((_, v: dict<number>): bool =>
                    v != {line: line('.'), col: virtcol('.')})

        else
            # ... otherwise, add the current position to the list of coordinates
            w:bd_marks.coords = w:bd_marks.coords + [{
                line: line('.'),
                col: virtcol('.'),
                }]
        endif

    else
    # Otherwise, if we're marking a character on a different line, reset
    # completely the list of coordinates.

        w:bd_marks.coords = [{
            line: line('.'),
            col: virtcol('.'),
            }]
    endif
enddef
# }}}1
# Util {{{1
def Getcml(): list<string> #{{{2
    var cml_left: string
    var cml_right: string
    if &l:cms == '' || &ft == 'markdown'
        [cml_left, cml_right] = ['', '']
    elseif &ft == 'vim'
        [cml_left, cml_right] = IsVim9() ? ['#', ''] : ['"', '']
    else
        [cml_left, cml_right] = split(&l:cms, '%s', true)
    endif
    return [cml_left, cml_right]
enddef

