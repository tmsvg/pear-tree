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
    let b:traverser = pear_tree#trie#Traverser(l:trie)
    let b:current_line = line('.')
    let b:current_column = col('.')
    let b:ignore = 0
endfunction


function! pear_tree#insert_mode#OnInsertCharPre() abort
    let b:current_column = col('.') + 1
    if !b:ignore
        call b:traverser.StepOrReset(v:char)
    else
        if b:traverser.AtWildcard()
            let b:traverser.wildcard_string .= v:char
        endif
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
        call b:traverser.TraverseBuffer([b:current_line, b:current_column - 1], [l:new_line, l:new_col - 1])
    endif
    let b:current_column = l:new_col
    let b:current_line = l:new_line
endfunction


" Define situations in which Pear Tree should close a simple opener.
function! s:ShouldCloseSimpleOpener(char) abort
    let l:closer = pear_tree#GetRule(a:char, 'closer')
    let l:next_char = pear_tree#cursor#NextChar()
    let l:prev_char = pear_tree#cursor#PrevChar()
    let l:is_dumb = pear_tree#IsDumbPair(a:char)

    if l:next_char =~# '\w' || (l:is_dumb && l:prev_char =~# '\w')
        return 0
    elseif !pear_tree#cursor#OnEmptyLine()
                \ && !pear_tree#cursor#AtEndOfLine()
                \ && l:next_char !~# '\s'
                \ && l:next_char !=# l:closer
                \ && !(has_key(pear_tree#Pairs(), l:prev_char)
                    \ && pear_tree#GetRule(l:prev_char, 'closer') ==# l:next_char)
        return 0
    elseif !l:is_dumb && get(g:, 'pear_tree_smart_openers', get(b:, 'pear_tree_smart_openers', 0))
        " Get the first closer after the cursor not preceded by an opener.
        let l:not_in = pear_tree#GetRule(a:char, 'not_in')

        let l:opener_pos = pear_tree#buffer#Search(a:char, pear_tree#cursor#Position(), l:not_in)
        let l:closer_pos = pear_tree#buffer#Search(l:closer, pear_tree#cursor#Position(), l:not_in)
        while pear_tree#buffer#ComparePositions(l:opener_pos, l:closer_pos) < 0
                    \ && l:opener_pos != [-1, -1]
            let l:opener_pos[1] += 1
            let l:closer_pos[1] += 1
            let l:opener_pos = pear_tree#buffer#Search(a:char, l:opener_pos, l:not_in)
            let l:closer_pos = pear_tree#buffer#Search(l:closer, l:closer_pos, l:not_in)
        endwhile
        if l:opener_pos == [-1, -1]
            let l:opener_pos = pear_tree#buffer#End()
        endif
        let l:closer_pos = pear_tree#buffer#ReverseSearch(l:closer, l:opener_pos, l:not_in)
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
function! s:ShouldCloseComplexOpener() abort
    if strlen(pear_tree#string#Trim(pear_tree#cursor#TextBefore())) == 0
        return 0
    elseif pear_tree#cursor#AtEndOfLine()
                \ || pear_tree#cursor#NextChar() =~# '\s'
                \ || has_key(pear_tree#Pairs(), pear_tree#cursor#NextChar())
                \ || pear_tree#GetSurroundingPair() != []
        return 1
    else
        return 0
    endif
endfunction


function! pear_tree#insert_mode#CloseComplexOpener(opener, wildcard) abort
    if s:ShouldCloseComplexOpener()
        let l:closer = pear_tree#GenerateCloser(a:opener, a:wildcard, pear_tree#cursor#Position())
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
    endif
    if get(g:, 'pear_tree_smart_closers', get(b:, 'pear_tree_smart_closers', 0))
        if pear_tree#IsDumbPair(a:char)
            return 1
        endif
        for l:opener in keys(pear_tree#Pairs())
            if pear_tree#GetRule(l:opener, 'closer') ==# a:char
                break
            endif
        endfor
        let l:not_in = pear_tree#GetRule(l:opener, 'not_in')
        let l:opener_pos = pear_tree#buffer#ReverseSearch(l:opener, pear_tree#cursor#Position(), l:not_in)
        let l:closer_pos = pear_tree#buffer#ReverseSearch(a:char, pear_tree#cursor#Position(), l:not_in)
        while pear_tree#buffer#ComparePositions(l:opener_pos, l:closer_pos) < 0
                    \ && l:closer_pos != [-1, -1]
            let l:opener_pos[1] -= 1
            let l:closer_pos[1] -= 1
            let l:opener_pos = pear_tree#buffer#ReverseSearch(l:opener, l:opener_pos, l:not_in)
            let l:closer_pos = pear_tree#buffer#ReverseSearch(a:char, l:closer_pos, l:not_in)
        endwhile
        if l:closer_pos == [-1, -1]
            let l:closer_pos = [1, 0]
        endif
        let l:opener_pos = pear_tree#buffer#Search(l:opener, l:closer_pos, l:not_in)
        let l:opener_pos[1] -= 1
        return l:opener_pos == [-1, -1] || pear_tree#IsBalancedOpener(l:opener, '', l:opener_pos) != [-1, -1]
    else
        return 1
    endif
endfunction


function! pear_tree#insert_mode#HandleCloser(char) abort
    if s:ShouldSkipCloser(a:char)
        return "\<Del>" . a:char
    elseif pear_tree#IsDumbPair(a:char)
        return a:char . pear_tree#insert_mode#CloseSimpleOpener(a:char)
    else
        return a:char
    endif
endfunction


" Called when pressing the last character in an opener string.
function! pear_tree#insert_mode#TerminateOpener(char) abort
    if s:IsCloser(a:char)
        let l:opener_end = pear_tree#insert_mode#HandleCloser(a:char)
    else
        let l:opener_end = a:char
    endif
    " If entered a simple (length of 1) opener and not currently typing
    " a longer strict sequence, handle the trivial pair.
    if has_key(pear_tree#Pairs(), a:char)
                \ && (b:traverser.GetString() ==# ''
                    \ || b:traverser.AtWildcard()
                    \ || !pear_tree#trie#HasChild(b:traverser.GetCurrent(), a:char)
                    \ )
        if pear_tree#IsDumbPair(a:char)
            return l:opener_end
        else
            return l:opener_end . pear_tree#insert_mode#CloseSimpleOpener(a:char)
        endif
    elseif b:traverser.StepToChild(a:char) && b:traverser.AtEndOfString()
        let l:not_in = pear_tree#GetRule(b:traverser.GetString(), 'not_in')
        if pear_tree#cursor#SyntaxRegion() =~? join(l:not_in, '\|')
            let b:ignore = b:ignore + 1
        endif
        return l:opener_end . pear_tree#insert_mode#CloseComplexOpener(b:traverser.GetString(), b:traverser.GetWildcardString())
    else
        let b:ignore = b:ignore + 1
        return l:opener_end
    endif
endfunction
