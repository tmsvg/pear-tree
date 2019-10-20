" Pear Tree - A painless, powerful Vim auto-pair plugin
" Maintainer: Thomas Savage <thomasesavage@gmail.com>
" Version: 0.8
" License: MIT
" Website: https://github.com/tmsvg/pear-tree


let s:save_cpo = &cpoptions
set cpoptions&vim

if v:version > 704 || (v:version == 704 && has('patch849'))
    let s:LEFT = "\<C-g>U\<Left>"
    let s:RIGHT = "\<C-g>U\<Right>"
else
    let s:LEFT = "\<Left>"
    let s:RIGHT = "\<Right>"
endif


function! pear_tree#insert_mode#OnInsertEnter() abort
    if exists('b:pear_tree_traverser')
        return
    endif
    let l:trie = pear_tree#trie#New(keys(pear_tree#Pairs()))
    let b:pear_tree_traverser = pear_tree#trie_traverser#New(l:trie)

    let s:current_line = line('.')
    let s:current_column = col('.')

    let s:strings_to_expand = []
    let s:ignore = 0
    let s:lost_track = 1

    let s:traverser_start_pos = [1, 0]
endfunction


function! pear_tree#insert_mode#Unload() abort
    unlet! b:pear_tree_traverser
endfunction


function! s:CorrectTraverser() abort
    if s:lost_track
        call b:pear_tree_traverser.Reset()
        let s:traverser_start_pos = b:pear_tree_traverser.TraverseBuffer([1, 0], [line('.'), col('.') - 1])
        let s:lost_track = 0
    elseif pumvisible()
        let l:old_pos = [s:current_line, s:current_column - 1]
        let l:new_pos = [line('.'), col('.') - 1]
        " Characters inserted by autocomplete are not caught by InsertCharPre.
        call b:pear_tree_traverser.WeakTraverseBuffer(l:old_pos, l:new_pos)
    endif
endfunction


function! pear_tree#insert_mode#OnInsertCharPre() abort
    call s:CorrectTraverser()
    let s:current_column = col('.') + 1
    if !s:ignore
        call b:pear_tree_traverser.StepOrReset(v:char)
    else
        let s:ignore = 0
    endif
endfunction


function! pear_tree#insert_mode#OnCursorMovedI() abort
    let l:new_line = line('.')
    let l:new_col = col('.')
    if l:new_line != s:current_line || l:new_col < s:current_column
        let s:lost_track = 1
    elseif l:new_col > s:current_column
        let l:old_pos = [s:current_line, s:current_column - 1]
        let l:new_pos = [l:new_line, l:new_col - 1]
        if s:lost_track
            call b:pear_tree_traverser.Reset()
            let s:traverser_start_pos = b:pear_tree_traverser.TraverseBuffer([1, 0], l:new_pos)
            let s:lost_track = 0
        elseif b:pear_tree_traverser.AtRoot()
            let s:traverser_start_pos = b:pear_tree_traverser.TraverseBuffer(l:old_pos, l:new_pos)
        else
            call b:pear_tree_traverser.WeakTraverseBuffer(l:old_pos, l:new_pos)
            if b:pear_tree_traverser.AtEndOfString()
                call b:pear_tree_traverser.Reset()
            endif
        endif
    endif
    let s:current_column = l:new_col
    let s:current_line = l:new_line
endfunction


function! s:ValidBefore(opener, closer, wildcard) abort
    let l:len = strlen(a:opener)
    if a:wildcard !=# ''
        let l:len = l:len + strlen(a:wildcard) - 1
    endif
    let l:text_before_cursor = pear_tree#cursor#TextBefore()
    let l:text_before_opener = l:text_before_cursor[:-l:len]

    let l:not_at = pear_tree#GetRule(a:opener, 'not_at')
    if l:not_at != [] && l:text_before_opener =~# join(l:not_at, '$\|') . '$'
        return 0
    elseif !pear_tree#IsDumbPair(a:opener)
        return 1
    elseif l:text_before_cursor[-l:len:] ==# a:opener
        return 0
    elseif pear_tree#IsCloser(l:text_before_opener[-1:])
        return 0
    else
        return 1
    endif
endfunction


function! s:ValidAfter(opener, closer, ...) abort
    let l:traverser = a:0 ? a:1 : b:pear_tree_traverser
    let l:next_char = pear_tree#cursor#NextChar()
    let l:node = pear_tree#trie#GetChild(l:traverser.GetCurrent(), l:next_char)
    " A character after the cursor is allowed if it ends a wildcard opener.
    if l:node != {} && l:node.is_end_of_string
                \ && l:traverser.AtWildcard()
                \ && a:opener[-1:] != l:next_char
        return 1
    elseif l:next_char !~# '\S' || pear_tree#IsCloser(l:next_char)
        return !pear_tree#IsDumbPair(l:next_char)
                    \ || l:next_char ==# a:opener[-1:]
    else
        return 0
    endif
endfunction


" Determine if Pear Tree should auto-close an opener of length 1.
function! s:ShouldCloseSimpleOpener(char) abort
    let l:is_dumb = pear_tree#IsDumbPair(a:char)
    let l:closer = pear_tree#GetRule(a:char, 'closer')

    let l:valid_before = s:ValidBefore(a:char, l:closer, '')
    let l:valid_after = s:ValidAfter(a:char, l:closer)

    if !l:valid_before || !l:valid_after
        let l:pair = pear_tree#GetSurroundingPair()
        if l:pair == []
            return 0
        elseif l:pair[0] ==# l:pair[1]
            return 0
        elseif l:is_dumb
            let [l:lnum, l:col] = pear_tree#cursor#Position()
            return [l:lnum, l:col - 2] == l:pair[3]
        endif
    elseif l:is_dumb || !pear_tree#GetOption('smart_openers')
        return 1
    endif

    let l:timeout_length = pear_tree#GetOption('timeout')

    " Ignore closers that are pending in s:strings_to_expand
    let l:strings_to_expand = join(s:strings_to_expand, '')
    let l:ignore = pear_tree#string#Count(l:strings_to_expand, l:closer)
    let l:ignore = l:ignore - pear_tree#string#Count(l:strings_to_expand, a:char)

    let l:closer_pos = pear_tree#GetOuterPair(a:char, l:closer,
                                            \ [line('.'), col('.') - 1],
                                            \ l:timeout_length)
    if l:closer_pos == [-1, -1] && l:ignore > 0
        let l:closer_pos = pear_tree#cursor#Position()
    else
        let l:opener_pos = pear_tree#IsBalancedPair(a:char, '',
                                                  \ l:closer_pos,
                                                  \ l:ignore,
                                                  \ l:timeout_length)
        if l:opener_pos == [-1, -1]
            let l:opener_pos = [1, 0]
        elseif l:opener_pos == [0, 0]
            " Function timed out
            return 0
        endif
        let l:closer_pos = pear_tree#GetOuterPair(a:char, l:closer,
                                                \ l:opener_pos,
                                                \ l:timeout_length)
        if l:closer_pos == [0, 0]
            " Function timed out
            return 1
        endif
    endif
    return l:closer_pos[0] == -1
                \ || pear_tree#IsBalancedPair(a:char, '',
                                            \ l:closer_pos,
                                            \ l:ignore,
                                            \ l:timeout_length) != [-1, -1]
endfunction


function! pear_tree#insert_mode#CloseSimpleOpener(char) abort
    if s:ShouldCloseSimpleOpener(a:char)
        let l:pos = pear_tree#cursor#Position()
        let l:closer = pear_tree#GenerateCloser(a:char, '', l:pos)
        let l:closer_length = pear_tree#string#VisualLength(l:closer)
        return l:closer . repeat(s:LEFT, l:closer_length)
    else
        return ''
    endif
endfunction


" Determine if Pear Tree should auto-close an opener of length > 1.
function! s:ShouldCloseComplexOpener(opener, closer, wildcard, traverser) abort
    let l:text_before_cursor = pear_tree#cursor#TextBefore()
    let l:is_dumb = pear_tree#IsDumbPair(a:opener)

    " The wildcard string can span multiple lines, but the opener
    " should not be terminated when the terminating character is the only
    " character on the line.
    if l:text_before_cursor =~# '^\s*$'
        return 0
    endif

    let l:valid_before = s:ValidBefore(a:opener, a:closer, a:wildcard)
    let l:valid_after = s:ValidAfter(a:opener, a:closer, a:traverser)

    if !l:valid_before || !l:valid_after
        let l:pair = pear_tree#GetSurroundingPair()
        if l:pair == []
            return 0
        elseif l:is_dumb
            let [l:lnum, l:col] = pear_tree#cursor#Position()
            let l:col = l:col - strlen(a:opener . a:wildcard) - 1
            if [l:lnum, l:col] != l:pair[3]
                return 0
            endif
        endif
    elseif l:is_dumb || !pear_tree#GetOption('smart_openers')
        return 1
    endif

    let l:trimmed_wildcard = pear_tree#TrimWildcard(a:opener, a:wildcard)
    let l:cursor_pos = [line('.'), col('.') - 1]

    let l:timeout_length = pear_tree#GetOption('timeout')

    if a:wildcard !=# ''
        let l:closer_pos = pear_tree#GetOuterWildcardPair(a:opener, a:closer,
                                                        \ l:trimmed_wildcard,
                                                        \ l:cursor_pos,
                                                        \ l:timeout_length)
    else
        let l:closer_pos = pear_tree#GetOuterPair(a:opener, a:closer,
                                                \ l:cursor_pos,
                                                \ l:timeout_length)
    endif
    " Ignore closers that are pending in s:strings_to_expand
    let l:ignore = pear_tree#string#Count(join(s:strings_to_expand, ''), a:closer)
    if l:closer_pos == [-1, -1] && l:ignore > 0
        let l:closer_pos = l:cursor_pos
    endif
    " An {opener} may be complete in the buffer if a smaller pair surrounds it
    " (e.g. <: > and <*>: </*>), even if the user has not finished typing it.
    " We should ignore the {opener} being typed when checking pair balance.
    let l:next_char = pear_tree#cursor#NextChar()
    if l:next_char ==# a:opener[-1:] && pear_tree#IsCloser(l:next_char)
        let l:ignore = l:ignore + 1
    endif
    return pear_tree#buffer#ComparePositions(l:closer_pos, l:cursor_pos) < 0
                \ || pear_tree#IsBalancedPair(a:opener, l:trimmed_wildcard,
                                            \ l:closer_pos, l:ignore,
                                            \ l:timeout_length, 1) != [-1, -1]
endfunction


function! pear_tree#insert_mode#CloseComplexOpener(opener, wildcard, ...) abort
    let l:traverser = a:0 ? a:1 : b:pear_tree_traverser
    let l:pos = pear_tree#cursor#Position()
    let l:closer = pear_tree#GenerateCloser(a:opener, a:wildcard, l:pos)
    let l:filter = 'pear_tree#string#EndsWith(l:closer, v:val[''closer''])'
    let l:ends_in_closer = filter(values(pear_tree#Pairs()), l:filter)
    if l:ends_in_closer != [] && l:closer[-1:] !=# a:opener[-1:]
        let l:pair_at_cursor = pear_tree#GetSurroundingPair()
        if l:pair_at_cursor != [] && pear_tree#string#EndsWith(l:closer, l:pair_at_cursor[1])
            let l:closer = l:closer[:-strlen(l:pair_at_cursor[1]) - 1]
        endif
    endif
    if s:ShouldCloseComplexOpener(a:opener, l:closer, a:wildcard, l:traverser)
        return l:closer . repeat(s:LEFT, pear_tree#string#VisualLength(l:closer))
    else
        return ''
    endif
endfunction


function! s:ShouldSkipCloser(char) abort
    if pear_tree#cursor#NextChar() !=# a:char
        return 0
    elseif pear_tree#IsDumbPair(a:char)
        return 1
    elseif !pear_tree#GetOption('smart_closers')
        return 1
    endif

    let l:timeout_length = pear_tree#GetOption('timeout')
    let l:pairs = copy(pear_tree#Pairs())
    for l:opener in keys(filter(l:pairs, 'v:val.closer ==# a:char'))
        " Ignore closers that are pending in s:strings_to_expand
        let l:strings_to_expand = join(s:strings_to_expand, '')
        let l:ignore = pear_tree#string#Count(l:strings_to_expand, a:char)
                     \ - pear_tree#string#Count(l:strings_to_expand, l:opener)

        let l:closer_pos = pear_tree#GetOuterPair(l:opener, a:char,
                                                \ [line('.'), col('.') - 1],
                                                \ l:timeout_length)
        let l:opener_pos = pear_tree#IsBalancedPair(l:opener, '',
                                                  \ l:closer_pos,
                                                  \ l:ignore,
                                                  \ l:timeout_length)
        let l:closer_pos = pear_tree#GetOuterPair(l:opener, a:char,
                                                \ l:opener_pos,
                                                \ l:timeout_length)

        if l:closer_pos[0] < 1
            let l:closer_pos = pear_tree#cursor#Position()
        endif
        let l:ignore = l:ignore + 1
        let l:opener_pos = pear_tree#IsBalancedPair(l:opener, '',
                                                  \ l:closer_pos,
                                                  \ l:ignore,
                                                  \ l:timeout_length)
        " IsBalancedPair returns [0, 0] if and only if it times out.
        if l:closer_pos[0] >= 0 && l:opener_pos[0] <= 0
            return 1
        endif
    endfor
    return 0
endfunction


function! pear_tree#insert_mode#HandleCloser(char) abort
    if s:ShouldSkipCloser(a:char)
        return s:RIGHT
    elseif pear_tree#IsDumbPair(a:char)
        return a:char . pear_tree#insert_mode#CloseSimpleOpener(a:char)
    else
        return a:char
    endif
endfunction


function! s:ShouldDeletePair() abort
    let l:prev_char = pear_tree#cursor#PrevChar()
    let l:next_char = pear_tree#cursor#NextChar()
    if !has_key(pear_tree#Pairs(), l:prev_char)
        return 0
    elseif pear_tree#GetRule(l:prev_char, 'closer') !=# l:next_char
        return 0
    elseif pear_tree#IsDumbPair(l:prev_char)
        return 1
    elseif !pear_tree#GetOption('smart_backspace')
        return 1
    endif

    let l:timeout_length = pear_tree#GetOption('timeout')

    " Ignore closers that are pending in s:strings_to_expand
    let l:strings_to_expand = join(s:strings_to_expand, '')
    let l:ignore = pear_tree#string#Count(l:strings_to_expand, l:next_char) + 1

    let l:closer_pos = pear_tree#GetOuterPair(l:prev_char, l:next_char,
                                            \ [line('.'), col('.') - 1],
                                            \ l:timeout_length)
    let l:opener_pos = pear_tree#IsBalancedPair(l:prev_char, '',
                                              \ l:closer_pos,
                                              \ l:ignore, l:timeout_length)
    let l:opener_pos[1] += 1
    let l:closer_pos = pear_tree#GetOuterPair(l:prev_char, l:next_char,
                                            \ l:opener_pos, l:timeout_length)

    if l:closer_pos[0]
        return pear_tree#IsBalancedPair(l:prev_char, '',
                                      \ l:closer_pos,
                                      \ l:ignore, l:timeout_length)[0] < 1
    else
        return 0
    endif
endfunction


function! pear_tree#insert_mode#Backspace() abort
    if s:ShouldDeletePair()
        return "\<Del>\<BS>"
    else
        return "\<BS>"
    endif
endfunction


function! pear_tree#insert_mode#PrepareExpansion() abort
    let l:prev_char = pear_tree#cursor#PrevChar()
    if filter(keys(pear_tree#Pairs()), 'v:val[-1:] ==# l:prev_char') == []
        return "\<CR>"
    endif
    let l:pair = pear_tree#GetSurroundingPair()
    if l:pair == []
        return "\<CR>"
    elseif !pear_tree#GetOption('repeatable_expand')
        return "\<CR>\<C-c>O"
    endif
    let l:opener_pos = l:pair[3]
    let l:cursor_pos = pear_tree#cursor#Position()
    if l:opener_pos == [l:cursor_pos[0], l:cursor_pos[1] - 2]
        let l:text_after_cursor = pear_tree#cursor#TextAfter()
        let l:text_length = pear_tree#string#VisualLength(l:text_after_cursor)
        call add(s:strings_to_expand, l:text_after_cursor)
        return repeat("\<Del>", l:text_length) . "\<CR>"
    else
        return "\<CR>"
    endif
endfunction


function! pear_tree#insert_mode#Expand() abort
    if s:strings_to_expand == []
        return "\<Esc>"
    else
        let l:expanded_strings = join(reverse(s:strings_to_expand), "\<CR>")
        let s:strings_to_expand = []
        let [l:lnum, l:col] = pear_tree#cursor#Position()
        let l:restore_pos = string([l:lnum, max([l:col - 1, 1])])
        return repeat(s:RIGHT, col('$') - l:col)
                    \ . "\<CR>" . l:expanded_strings . "\<Esc>"
                    \ . ':call cursor(' . l:restore_pos . ')' . "\<CR>"
    endif
endfunction


function! pear_tree#insert_mode#JumpOut() abort
    let l:pair = pear_tree#GetSurroundingPair()
    if l:pair == []
        return ''
    endif
    let l:col = col('.')
    let [l:opener, l:closer, l:wildcard, l:pos] = l:pair
    let l:closer = pear_tree#GenerateCloser(l:opener, l:wildcard, [0, 0])
    let l:num_spaces = stridx(getline('.'), l:closer, l:col - 1) - l:col + 1
    return repeat(s:RIGHT, pear_tree#string#VisualLength(l:closer) + l:num_spaces)
endfunction


function! pear_tree#insert_mode#JumpNReturn() abort
    return pear_tree#insert_mode#JumpOut() . "\<CR>"
endfunction


function! pear_tree#insert_mode#ExpandOne() abort
    if s:strings_to_expand == []
        return ''
    endif
    return remove(s:strings_to_expand, -1)
endfunction


function! pear_tree#insert_mode#Space() abort
    let l:pair = pear_tree#GetSurroundingPair()
    if l:pair == [] || pear_tree#IsDumbPair(l:pair[0])
        return "\<Space>"
    endif
    let l:opener_pos = l:pair[3]
    let l:cursor_pos = pear_tree#cursor#Position()
    if l:opener_pos == [l:cursor_pos[0], l:cursor_pos[1] - 2]
        return "\<Space>\<Space>" . s:LEFT
    else
        return "\<Space>"
    endif
endfunction


" Called when pressing the last character in an opening string. The function
" returns {char} as well as the corresponding closing string if {char}
" completes an opening string contained in pear_tree_pairs.
function! pear_tree#insert_mode#TerminateOpener(char) abort
    call s:CorrectTraverser()

    " Handle single-character openers and closers that may be typed within a
    " wildcard string.
    if pear_tree#IsCloser(a:char) && pear_tree#cursor#NextChar() ==# a:char
        let l:opener_end = s:RIGHT
    elseif has_key(pear_tree#Pairs(), a:char)
                \ && (b:pear_tree_traverser.AtRoot() || b:pear_tree_traverser.AtWildcard()
                    \ || !pear_tree#trie#HasChild(b:pear_tree_traverser.GetCurrent(), a:char))
        let l:opener_end = a:char . pear_tree#insert_mode#CloseSimpleOpener(a:char)
    else
        let l:opener_end = a:char
    endif

    " Allow multi-character opening strings to be auto-paired within a
    " wildcard string. Rescan the buffer starting after the start of the
    " current wildcard opener and see if {char} terminates another opener.
    if b:pear_tree_traverser.AtWildcard()
                \ && !pear_tree#trie#HasChild(b:pear_tree_traverser.GetCurrent(), a:char)
                \ && filter(keys(pear_tree#Pairs()),
                          \ 'strlen(v:val) > 1 && v:val[-1:] ==# a:char') != []
        let l:save_traverser = deepcopy(b:pear_tree_traverser)
        let l:start_pos = copy(s:traverser_start_pos)
        let l:start_pos[1] += 1

        call b:pear_tree_traverser.Reset()
        let l:end_pos = [s:current_line, s:current_column - 1]
        call b:pear_tree_traverser.TraverseBuffer(l:start_pos, l:end_pos)
        if !has_key(pear_tree#Pairs(), b:pear_tree_traverser.GetString() . a:char)
            let b:pear_tree_traverser = l:save_traverser
        endif
    endif
    let l:node = pear_tree#trie#GetChild(b:pear_tree_traverser.GetCurrent(), a:char)
    if l:node != {} && l:node.is_end_of_string
        let l:string = b:pear_tree_traverser.GetString() . escape(a:char, '*')
        let l:not_in = pear_tree#GetRule(l:string, 'not_in')
        if l:not_in != [] && pear_tree#cursor#SyntaxRegion() =~? join(l:not_in, '\|')
            if b:pear_tree_traverser.AtWildcard()
                " The terminating character should become part of the wildcard
                " string if it is entered in a `not_in` syntax region.
                let s:ignore = 1
                let b:pear_tree_traverser.wildcard_string .= a:char
            else
                call b:pear_tree_traverser.Reset()
            endif
        elseif strlen(l:string) > 1
            let l:wildcard = b:pear_tree_traverser.GetWildcardString()
            let l:opener_end .= pear_tree#insert_mode#CloseComplexOpener(l:string, l:wildcard, get(l:, 'save_traverser', b:pear_tree_traverser))
        endif
    endif
    let b:pear_tree_traverser = get(l:, 'save_traverser', b:pear_tree_traverser)
    return l:opener_end
endfunction


let &cpoptions = s:save_cpo
unlet s:save_cpo
