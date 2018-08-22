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
    let b:current_line = line('.')
    let b:current_column = col('.')
    let b:ignore = 0
endfunction


function! pear_tree#insert_mode#OnInsertCharPre() abort
    " Characters inserted by autocomplete are not caught by InsertCharPre,
    " so the traverser must be corrected.
    if pumvisible()
        call b:traverser.WeakTraverseBuffer([b:current_line, b:current_column - 1], [line('.'), col('.') - 1])
    endif
    let b:current_column = col('.') + 1
    if !b:ignore
        call b:traverser.StepOrReset(v:char)
    else
        let b:ignore = b:ignore - 1
    endif
endfunction


function! pear_tree#insert_mode#OnCursorMovedI() abort
    let l:new_line = line('.')
    let l:new_col = col('.')
    if l:new_line != b:current_line || l:new_col < b:current_column
        call b:traverser.Reset()
        call b:traverser.TraverseBuffer([1, 0], [l:new_line, l:new_col - 1])
    elseif l:new_col > b:current_column
        if b:traverser.AtRoot()
            call b:traverser.TraverseBuffer([b:current_line, b:current_column - 1], [l:new_line, l:new_col - 1])
        else
            call b:traverser.WeakTraverseBuffer([b:current_line, b:current_column - 1], [l:new_line, l:new_col - 1])
            if b:traverser.AtEndOfString()
                call b:traverser.Reset()
            endif
        endif
    endif
    let b:current_column = l:new_col
    let b:current_line = l:new_line
endfunction


" Return the position of the end of the innermost pair that surrounds {start}.
function! s:GetOuterPair(opener, closer, start) abort
    let l:not_in = pear_tree#GetRule(a:opener, 'not_in')
    let l:opener_pos = pear_tree#buffer#Search(a:opener, pear_tree#cursor#Position(), l:not_in)
    let l:closer_pos = pear_tree#buffer#Search(a:closer, pear_tree#cursor#Position(), l:not_in)
    while pear_tree#buffer#ComparePositions(l:opener_pos, l:closer_pos) < 0
                \ && l:opener_pos != [-1, -1]
        let l:opener_pos[1] += 1
        let l:closer_pos[1] += 1
        let l:opener_pos = pear_tree#buffer#Search(a:opener, l:opener_pos, l:not_in)
        let l:closer_pos = pear_tree#buffer#Search(a:closer, l:closer_pos, l:not_in)
    endwhile
    if l:opener_pos == [-1, -1]
        let l:opener_pos = pear_tree#buffer#End()
    endif
    let l:closer_pos = pear_tree#buffer#ReverseSearch(a:closer, l:opener_pos, l:not_in)
    if pear_tree#buffer#ComparePositions(l:closer_pos, a:start) < 0
        let l:closer_pos = [-1, -1]
    endif
    return l:closer_pos
endfunction


" Define situations in which Pear Tree should close a simple opener.
function! s:ShouldCloseSimpleOpener(char) abort
    let l:closer = pear_tree#GetRule(a:char, 'closer')
    let l:next_char = pear_tree#cursor#NextChar()
    let l:prev_char = pear_tree#cursor#PrevChar()
    let l:is_dumb = pear_tree#IsDumbPair(a:char)

    if l:next_char =~# '\w'
                \ || (l:is_dumb && (l:prev_char =~# '\w' || l:prev_char ==# a:char))
        return 0
    elseif !pear_tree#cursor#OnEmptyLine()
                \ && !pear_tree#cursor#AtEndOfLine()
                \ && l:next_char !~# '\s'
                \ && l:next_char !=# l:closer
                \ && pear_tree#GetSurroundingPair() == []
        return 0
    elseif !l:is_dumb && get(b:, 'pear_tree_smart_openers', get(g:, 'pear_tree_smart_openers', 0))
        let l:closer_pos = s:GetOuterPair(a:char, l:closer, [line('.'), col('.') - 1])
        return l:closer_pos == [-1, -1] || pear_tree#IsBalancedPair(a:char, '', l:closer_pos) != [-1, -1]
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


function! s:GetOuterWildcardPair(opener, closer, wildcard, start) abort
    let l:not_in = pear_tree#GetRule(a:opener, 'not_in')
    let l:traverser = deepcopy(b:traverser)
    let l:idx = pear_tree#string#UnescapedStridx(a:opener, '*')
    let l:opener_hint = pear_tree#string#Encode(a:opener[:(l:idx)], '*', a:wildcard)
    let l:opener_pos = pear_tree#buffer#Search(l:opener_hint, a:start)
    let l:closer_pos = pear_tree#buffer#Search(a:closer, a:start, l:not_in)
    while l:opener_pos != [-1, -1]
                \ && (pear_tree#buffer#ComparePositions(l:opener_pos, l:closer_pos) < 0
                \ || l:traverser.WeakTraverseBuffer(l:opener_pos, pear_tree#buffer#End()) == [-1, -1]
                \ || pear_tree#GenerateCloser(l:traverser.GetString(), a:wildcard, [0, 0]) !=# a:closer)
        let l:opener_pos[1] += 1
        let l:closer_pos[1] += 1
        let l:opener_pos = pear_tree#buffer#Search(l:opener_hint, l:opener_pos)
        if pear_tree#buffer#ComparePositions(l:opener_pos, l:closer_pos) > 0
            let l:closer_pos = pear_tree#buffer#Search(a:closer, a:start, l:not_in)
        endif
    endwhile
    if l:opener_pos == [-1, -1]
        let l:opener_pos = pear_tree#buffer#End()
    endif
    let l:closer_pos = pear_tree#buffer#ReverseSearch(a:closer, l:opener_pos, l:not_in)
    return pear_tree#buffer#ReverseSearch(a:closer, l:opener_pos, l:not_in)
endfunction


" Define situations in which Pear Tree should close a complex opener.
" First, the wildcard string can span multiple lines, but the opener
" should not be terminated when the terminating character is the only
" character on the line. For example,
"           <div
"             class='foo'>|
" should match, but
"           <div
"             class='foo'
"           >|
" should not match.
" If it is the first case, the cursor should also be at the end of the
" line, before whitespace, or between another pair.
function! s:ShouldCloseComplexOpener(opener, closer, wildcard) abort
    if strlen(pear_tree#string#Trim(pear_tree#cursor#TextBefore())) == 0
        return 0
    elseif !(pear_tree#cursor#AtEndOfLine()
                \ || pear_tree#cursor#NextChar() =~# '\s'
                \ || has_key(pear_tree#Pairs(), pear_tree#cursor#NextChar())
                \ || pear_tree#GetSurroundingPair() != [])
        return 0
    elseif get(b:, 'pear_tree_smart_openers', get(g:, 'pear_tree_smart_openers', 0))
        if a:wildcard !=# ''
            let l:closer_pos = s:GetOuterWildcardPair(a:opener, a:closer, a:wildcard, [line('.'), col('.') - 1])
        else
            let l:closer_pos = s:GetOuterPair(a:opener, a:closer, [line('.'), col('.') - 1])
        endif
        return l:closer_pos == [-1, -1] || pear_tree#IsBalancedPair(a:opener, a:wildcard, l:closer_pos) != [-1, -1]
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


function! s:IsCloser(str) abort
    return index(map(values(pear_tree#Pairs()), 'v:val.closer'), a:str) > -1
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
        let l:closer_pos = s:GetOuterPair(l:opener, a:char, [line('.'), col('.') - 1])
        if l:closer_pos != [-1, -1] && pear_tree#IsBalancedPair(l:opener, '', l:closer_pos, 1) == [-1, -1]
            return 1
        endif
    endfor
    return 0
endfunction


function! pear_tree#insert_mode#HandleCloser(char) abort
    if s:ShouldSkipCloser(a:char)
        let b:ignore = b:ignore + 1
        return "\<Del>" . a:char
    elseif pear_tree#IsDumbPair(a:char)
        return a:char . pear_tree#insert_mode#CloseSimpleOpener(a:char)
    else
        return a:char
    endif
endfunction


" Called when pressing the last character in an opener string.
function! pear_tree#insert_mode#TerminateOpener(char) abort
    " Characters inserted by autocomplete are not caught by InsertCharPre,
    " so the traverser misses. This function triggers before CursorMovedI and
    " InsertCharPre, so the traverser must be corrected here.
    if pumvisible()
        call b:traverser.WeakTraverseBuffer([b:current_line, b:current_column - 1], [line('.'), col('.') - 1])
    endif
    if s:IsCloser(a:char)
        let l:opener_end = pear_tree#insert_mode#HandleCloser(a:char)
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
                let b:ignore = b:ignore + 1
                let b:traverser.wildcard_string .= a:char
            else
                call b:traverser.Reset()
            endif
        endif
        if strlen(b:traverser.GetString()) > 1
            return l:opener_end . pear_tree#insert_mode#CloseComplexOpener(b:traverser.GetString(), b:traverser.GetWildcardString())
        endif
    else
        let b:ignore = b:ignore + 1
    endif
    return l:opener_end
endfunction
