" Pear Tree - A painless, powerful Vim auto-pair plugin
" Maintainer: Thomas Savage <thomasesavage@gmail.com>
" Version: 0.5
" License: MIT
" Website: https://github.com/tmsvg/pear-tree


let s:save_cpo = &cpoptions
set cpoptions&vim

if v:version > 704 || (v:version == 704 && has('patch849'))
    let s:LEFT = "\<C-g>U" . "\<Left>"
    let s:RIGHT = "\<C-g>U" . "\<Right>"
else
    let s:LEFT = "\<Left>"
    let s:RIGHT = "\<Right>"
endif


function! pear_tree#insert_mode#Prepare() abort
    if exists('b:traverser')
        return
    endif
    let l:trie = pear_tree#trie#New(keys(pear_tree#Pairs()))
    let b:traverser = pear_tree#trie_traverser#New(l:trie)

    let s:current_line = line('.')
    let s:current_column = col('.')

    let s:strings_to_expand = []
    let s:ignore = 0
    let s:lost_track = 0
endfunction


function! s:CorrectTraverser() abort
    if s:lost_track
        call b:traverser.Reset()
        call b:traverser.TraverseBuffer([1, 0], [line('.'), col('.') - 1])
        let s:lost_track = 0
    elseif pumvisible()
        " Characters inserted by autocomplete are not caught by InsertCharPre,
        call b:traverser.WeakTraverseBuffer([s:current_line, s:current_column - 1], [line('.'), col('.') - 1])
    endif
endfunction


function! pear_tree#insert_mode#OnInsertCharPre() abort
    call s:CorrectTraverser()
    let s:current_column = col('.') + 1
    if !s:ignore
        call b:traverser.StepOrReset(v:char)
    endif
    let s:ignore = 0
endfunction


function! pear_tree#insert_mode#OnCursorMovedI() abort
    let l:new_line = line('.')
    let l:new_col = col('.')
    if l:new_line != s:current_line || l:new_col < s:current_column
        let s:lost_track = 1
    elseif l:new_col > s:current_column
        if s:lost_track
            call b:traverser.Reset()
            call b:traverser.TraverseBuffer([1, 0], [l:new_line, l:new_col - 1])
            let s:lost_track = 0
        elseif b:traverser.AtRoot()
            call b:traverser.TraverseBuffer([s:current_line, s:current_column - 1], [l:new_line, l:new_col - 1])
        else
            call b:traverser.WeakTraverseBuffer([s:current_line, s:current_column - 1], [l:new_line, l:new_col - 1])
            if b:traverser.AtEndOfString()
                call b:traverser.Reset()
            endif
        endif
    endif
    let s:current_column = l:new_col
    let s:current_line = l:new_line
endfunction


" Define situations in which Pear Tree should close a simple opener.
function! s:ShouldCloseSimpleOpener(char) abort
    let l:closer = pear_tree#GetRule(a:char, 'closer')
    let l:next_char = pear_tree#cursor#NextChar()
    let l:prev_char = pear_tree#cursor#PrevChar()
    let l:is_dumb = pear_tree#IsDumbPair(a:char)

    let l:valid_before = !l:is_dumb
                \ || (l:prev_char !~# '\w'
                \     && l:prev_char !=# a:char
                \     && !pear_tree#IsCloser(l:prev_char))
    let l:valid_after = (l:next_char !~# '\S'
                \        || l:next_char ==# l:closer)
    if !l:valid_before || !l:valid_after
        if pear_tree#IsDumbPair(l:next_char)
            return 0
        else
            let l:pair = pear_tree#GetSurroundingPair()
            if l:pair == []
                return 0
            elseif l:is_dumb
                        \ && pear_tree#buffer#ComparePositions([line('.'), col('.') - 2], get(l:pair, 3, [-1, -1])) != 0
                        \ && strridx(getline('.'), l:pair[1], col('.')) == col('.') - 1
                        \ && l:prev_char =~# '\S'
                return 0
            endif
        endif
    endif
    if !l:is_dumb && get(b:, 'pear_tree_smart_openers', get(g:, 'pear_tree_smart_openers', 0))
        " Ignore closers that are pending in s:strings_to_expand
        let l:strings_to_expand = join(s:strings_to_expand, '')
        let l:ignore = count(l:strings_to_expand, l:closer) - count(l:strings_to_expand, a:char)

        let l:closer_pos = pear_tree#GetOuterPair(a:char, l:closer, [line('.'), col('.') - 1])
        if l:closer_pos == [-1, -1] && l:ignore > 0
            let l:closer_pos = pear_tree#cursor#Position()
        else
            let l:opener_pos = pear_tree#IsBalancedPair(a:char, '', l:closer_pos, l:ignore)
            if pear_tree#buffer#ComparePositions(l:opener_pos, [1, 0]) < 0
                let l:opener_pos = [1, 0]
            endif
            let l:closer_pos = pear_tree#GetOuterPair(a:char, l:closer, l:opener_pos)
        endif
        return l:closer_pos == [-1, -1] || pear_tree#IsBalancedPair(a:char, '', l:closer_pos, l:ignore) != [-1, -1]
    else
        return 1
    endif
endfunction


function! pear_tree#insert_mode#CloseSimpleOpener(char) abort
    if s:ShouldCloseSimpleOpener(a:char)
        let l:closer = pear_tree#GenerateCloser(a:char, '', pear_tree#cursor#Position())
        return l:closer . repeat(s:LEFT, pear_tree#string#VisualLength(l:closer))
    else
        return ''
    endif
endfunction


" Define situations in which Pear Tree should close a complex opener.
function! s:ShouldCloseComplexOpener(opener, closer, wildcard) abort
    " The wildcard string can span multiple lines, but the opener
    " should not be terminated when the terminating character is the only
    " character on the line.
    if strlen(pear_tree#string#Trim(pear_tree#cursor#TextBefore())) == 0
        return 0
    " The cursor should also be at the end of the line, before whitespace,
    " or between another pair.
    elseif !(pear_tree#cursor#AtEndOfLine()
                \ || pear_tree#cursor#NextChar() =~# '\s'
                \ || has_key(pear_tree#Pairs(), pear_tree#cursor#NextChar())
                \ || pear_tree#GetSurroundingPair() != [])
        return 0
    elseif get(b:, 'pear_tree_smart_openers', get(g:, 'pear_tree_smart_openers', 0))
        let l:trimmed_wildcard = pear_tree#TrimWildcard(a:opener, a:wildcard)
        let l:cursor_pos = [line('.'), col('.') - 1]
        if a:wildcard !=# ''
            let l:closer_pos = pear_tree#GetOuterWildcardPair(a:opener, a:closer, l:trimmed_wildcard, l:cursor_pos)
        else
            let l:closer_pos = pear_tree#GetOuterPair(a:opener, a:closer, l:cursor_pos)
        endif
        " Ignore closers that are pending in s:strings_to_expand
        let l:ignore = count(join(s:strings_to_expand, ''), a:closer)
        if l:closer_pos == [-1, -1] && l:ignore > 0
            let l:closer_pos = l:cursor_pos
        endif
        " An {opener} may be complete in the buffer if a smaller pair surrounds
        " it (e.g. <: > and <*>: </*>), even if the user has not finished
        " typing it. When skipping a closer such as `>`, s:ignore should be 1.
        " Use it to ignore the {opener} being typed when checking pair balance.
        let l:ignore = l:ignore + s:ignore
        return pear_tree#buffer#ComparePositions(l:closer_pos, l:cursor_pos) < 0
                    \ || pear_tree#IsBalancedPair(a:opener, l:trimmed_wildcard, l:closer_pos, l:ignore, 1) != [-1, -1]
    else
        return 1
    endif
endfunction


function! pear_tree#insert_mode#CloseComplexOpener(opener, wildcard) abort
    let l:closer = pear_tree#GenerateCloser(a:opener, a:wildcard, pear_tree#cursor#Position())
    if s:ShouldCloseComplexOpener(a:opener, l:closer, a:wildcard)
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
    elseif !get(b:, 'pear_tree_smart_closers', get(g:, 'pear_tree_smart_closers', 0))
        return 1
    endif
    for l:opener in keys(filter(copy(pear_tree#Pairs()), 'v:val.closer ==# a:char'))
        " Ignore closers that are pending in s:strings_to_expand
        let l:strings_to_expand = join(s:strings_to_expand, '')
        let l:ignore = count(l:strings_to_expand, a:char) - count(l:strings_to_expand, l:opener)

        let l:closer_pos = pear_tree#GetOuterPair(l:opener, a:char, [line('.'), col('.') - 1])
        let l:opener_pos = pear_tree#IsBalancedPair(l:opener, '', l:closer_pos, l:ignore)
        let l:closer_pos = pear_tree#GetOuterPair(l:opener, a:char, l:opener_pos)

        if l:closer_pos == [-1, -1]
            let l:closer_pos = pear_tree#cursor#Position()
        endif
        if l:closer_pos[0] != -1 && pear_tree#IsBalancedPair(l:opener, '', l:closer_pos, l:ignore + 1) == [-1, -1]
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
    elseif get(b:, 'pear_tree_smart_backspace', get(g:, 'pear_tree_smart_backspace', 0))
        " Ignore closers that are pending in s:strings_to_expand
        let l:ignore = count(join(s:strings_to_expand, ''), l:next_char) + 1

        let l:closer_pos = pear_tree#GetOuterPair(l:prev_char, l:next_char, [line('.'), col('.') - 1])
        let l:opener_pos = pear_tree#IsBalancedPair(l:prev_char, '', l:closer_pos, l:ignore)
        let l:opener_pos[1] += 1
        let l:closer_pos = pear_tree#GetOuterPair(l:prev_char, l:next_char, l:opener_pos)

        " Will deleting both make the next closer unbalanced?
        return pear_tree#IsBalancedPair(l:prev_char, '', l:closer_pos, l:ignore) == [-1, -1]
    else
        return 1
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
    endif
    let l:opener_pos = l:pair[3]
    let l:cursor_pos = pear_tree#cursor#Position()
    if l:opener_pos[0] == l:cursor_pos[0] && l:opener_pos[1] == l:cursor_pos[1] - 2
        let l:text_after_cursor = pear_tree#cursor#TextAfter()
        call add(s:strings_to_expand, l:text_after_cursor)
        return repeat("\<Del>", pear_tree#string#VisualLength(l:text_after_cursor)) . "\<CR>"
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
        return repeat(s:RIGHT, col('$') - l:col)
                    \ . "\<CR>" . l:expanded_strings . "\<Esc>"
                    \ . ':call cursor(' . string([l:lnum, max([l:col - 1, 1])]) . ')' . "\<CR>"
    endif
endfunction


function! pear_tree#insert_mode#JumpOut() abort
    let l:pair = pear_tree#GetSurroundingPair()
    if l:pair == []
        return ''
    endif
    let [l:opener, l:closer, l:wildcard] = l:pair[:2]
    let l:closer = pear_tree#GenerateCloser(l:opener, l:wildcard, [0, 0])
    return repeat(s:RIGHT, pear_tree#string#VisualLength(l:closer))
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


" Called when pressing the last character in an opener string.
function! pear_tree#insert_mode#TerminateOpener(char) abort
    call s:CorrectTraverser()
    if pear_tree#IsCloser(a:char) && pear_tree#cursor#NextChar() ==# a:char
        let l:opener_end = s:RIGHT
    elseif has_key(pear_tree#Pairs(), a:char)
        let l:opener_end = a:char . pear_tree#insert_mode#CloseSimpleOpener(a:char)
    else
        let l:opener_end = a:char
    endif
    if b:traverser.StepToChild(a:char) && b:traverser.AtEndOfString()
        let l:not_in = pear_tree#GetRule(b:traverser.GetString(), 'not_in')
        if l:not_in != [] && pear_tree#cursor#SyntaxRegion() =~? join(l:not_in, '\|')
            call b:traverser.StepToParent()
            if b:traverser.AtWildcard()
                " The terminating character should become part of the wildcard
                " string if it is entered in a `not_in` syntax region.
                let s:ignore = 1
                let b:traverser.wildcard_string .= a:char
            else
                call b:traverser.Reset()
            endif
        elseif strlen(b:traverser.GetString()) > 1
            return l:opener_end . pear_tree#insert_mode#CloseComplexOpener(b:traverser.GetString(), b:traverser.GetWildcardString())
        endif
    else
        let s:ignore = 1
    endif
    return l:opener_end
endfunction


let &cpoptions = s:save_cpo
unlet s:save_cpo
