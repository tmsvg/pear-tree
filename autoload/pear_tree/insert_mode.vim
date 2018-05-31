if v:version > 704 || (v:version == 704 && has('patch849'))
    let s:LEFT = "\<C-g>U" . "\<Left>"
    let s:RIGHT = "\<C-g>U" . "\<Right>"
else
    let s:LEFT = "\<Left>"
    let s:RIGHT = "\<Right>"
endif


function! pear_tree#insert_mode#Prepare() abort
    if exists('s:traverser')
        return
    endif
    let l:trie = pear_tree#trie#New(keys(pear_tree#Pairs()))
    let s:traverser = pear_tree#trie#Traverser(l:trie)
    let s:current_line = line('.')
    let s:current_column = col('.')
    let s:ignore = 0
endfunction


function! pear_tree#insert_mode#OnInsertCharPre() abort
    let s:current_column = col('.') + 1
    if !s:ignore
        call s:traverser.StepOrReset(v:char)
    else
        if s:traverser.AtWildcard()
            let s:traverser.wildcard_string .= v:char
        endif
        let s:ignore = s:ignore - 1
    endif
endfunction


function! pear_tree#insert_mode#OnCursorMovedI() abort
    let l:new_line = line('.')
    let l:new_col = col('.')
    if l:new_line != s:current_line || l:new_col < s:current_column
        call s:traverser.Reset()
        call s:traverser.TraverseBuffer([1, 0], [l:new_line, l:new_col - 1])
    elseif l:new_col > s:current_column
        call s:traverser.TraverseBuffer([s:current_line, s:current_column - 1], [l:new_line, l:new_col - 1])
    endif
    let s:current_column = l:new_col
    let s:current_line = l:new_line
endfunction


" Define situations in which Pear Tree should close a simple opener.
function! s:ShouldCloseSimpleOpener(char) abort
    let l:delim = pear_tree#GetRule(a:char, 'delimiter')
    let l:next_char = pear_tree#cursor#NextChar()
    let l:prev_char = pear_tree#cursor#PrevChar()
    let l:is_dumb = pear_tree#IsDumbPair(a:char)

    if l:next_char =~# '\w' || (l:is_dumb && l:prev_char =~# '\w')
        return 0
    elseif !l:is_dumb && get(g:, 'pear_tree_smart_insert', get(b:, 'pear_tree_smart_insert', 0))
        if !pear_tree#cursor#OnEmptyLine()
                    \ && !pear_tree#cursor#AtEndOfLine()
                    \ && l:next_char !~# '\s'
                    \ && l:next_char !=# l:delim
            return 0
        endif
        " Get the first delimiter after the cursor not preceded by an opener.
        let l:not_in = pear_tree#GetRule(a:char, 'not_in')

        let l:opener_pos = pear_tree#buffer#Search(a:char, pear_tree#cursor#Position(), l:not_in)
        let l:delim_pos = pear_tree#buffer#Search(l:delim, pear_tree#cursor#Position(), l:not_in)
        if l:opener_pos != [-1, -1]
            while pear_tree#buffer#ComparePositions(l:opener_pos, l:delim_pos) < 0
                        \ && l:opener_pos != [-1, -1]
                let l:opener_pos[1] += 1
                let l:delim_pos[1] += 1
                let l:opener_pos = pear_tree#buffer#Search(a:char, l:opener_pos, l:not_in)
                let l:delim_pos = pear_tree#buffer#Search(l:delim, l:delim_pos, l:not_in)
            endwhile
            let l:delim_pos = pear_tree#buffer#ReverseSearch(l:delim, l:opener_pos, l:not_in)
        endif
        return l:delim_pos == [-1, -1] || pear_tree#IsBalancedPair(a:char, '', l:delim_pos) != [-1, -1]
    elseif pear_tree#cursor#OnEmptyLine()
                \ || pear_tree#cursor#AtEndOfLine()
                \ || l:next_char =~# '\s'
                \ || l:next_char ==# l:delim
        return 1
    elseif has_key(pear_tree#Pairs(), l:prev_char)
                \ && pear_tree#GetRule(l:prev_char, 'delimiter') ==# l:next_char
        return 1
    else
        return 0
    endif
endfunction


function! pear_tree#insert_mode#CloseSimpleOpener(char) abort
    if s:ShouldCloseSimpleOpener(a:char)
        let l:delim = pear_tree#GenerateDelimiter(a:char, '', pear_tree#cursor#Position())
        return l:delim . repeat(s:LEFT, pear_tree#string#VisualLength(l:delim))
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
        let l:delim = pear_tree#GenerateDelimiter(a:opener, a:wildcard, pear_tree#cursor#Position())
        return l:delim . repeat(s:LEFT, pear_tree#string#VisualLength(l:delim))
    else
        return ''
    endif
endfunction


function! s:ShouldSkipDelimiter(char) abort
    if pear_tree#cursor#NextChar() !=# a:char
        return 0
    elseif get(g:, 'pear_tree_smart_closers', get(b:, 'pear_tree_smart_closers', 0))
        if pear_tree#IsDumbPair(a:char)
            return 1
        endif
        for l:opener in keys(pear_tree#Pairs())
            if pear_tree#GetRule(l:opener, 'delimiter') ==# a:char
                break
            endif
        endfor
        let l:not_in = pear_tree#GetRule(l:opener, 'not_in')
        let l:opener_pos = pear_tree#buffer#ReverseSearch(l:opener, pear_tree#cursor#Position(), l:not_in)
        let l:delim_pos = pear_tree#buffer#ReverseSearch(a:char, pear_tree#cursor#Position(), l:not_in)
        if l:delim_pos != [-1, -1]
            while pear_tree#buffer#ComparePositions(l:opener_pos, l:delim_pos) < 0
                        \ && l:delim_pos != [-1, -1]
                let l:opener_pos[1] -= 1
                let l:delim_pos[1] -= 1
                let l:opener_pos = pear_tree#buffer#ReverseSearch(l:opener, l:opener_pos, l:not_in)
                let l:delim_pos = pear_tree#buffer#ReverseSearch(a:char, l:delim_pos, l:not_in)
            endwhile
            let l:opener_pos = pear_tree#buffer#Search(l:opener, l:delim_pos, l:not_in)
            let l:opener_pos[1] -= 1
        endif
        return l:opener_pos == [-1, -1] || pear_tree#IsBalancedOpener(l:opener, '', l:opener_pos) != [-1, -1]
    else
        return 1
    endif
endfunction


function! pear_tree#insert_mode#HandleDelimiter(char) abort
    if pear_tree#cursor#NextChar() ==# a:char && s:ShouldSkipDelimiter(a:char)
        return "\<Del>" . a:char
    elseif pear_tree#IsDumbPair(a:char)
        return a:char . pear_tree#insert_mode#CloseSimpleOpener(a:char)
    else
        return a:char
    endif
endfunction


" Called when pressing the last letter in an opener string.
function! pear_tree#insert_mode#TerminateOpener(char) abort
    " If entered a simple (length of 1) opener and not currently typing
    " a longer strict sequence, handle the trivial pair.
    if has_key(pear_tree#Pairs(), a:char)
                \ && (s:traverser.GetString() ==# ''
                    \ || s:traverser.AtWildcard()
                    \ || !pear_tree#trie#HasChild(s:traverser.GetCurrent(), a:char)
                    \ )
        if pear_tree#IsDumbPair(a:char)
            return pear_tree#insert_mode#HandleDelimiter(a:char)
        else
            return a:char . pear_tree#insert_mode#CloseSimpleOpener(a:char)
        endif
    elseif s:traverser.StepToChild(a:char) && s:traverser.AtEndOfString()
        let l:not_in = pear_tree#GetRule(s:traverser.GetString(), 'not_in')
        if pear_tree#cursor#SyntaxRegion() =~? join(l:not_in, '\|')
            let s:ignore = s:ignore + 1
        endif
        return a:char . pear_tree#insert_mode#CloseComplexOpener(s:traverser.GetString(), s:traverser.GetWildcardString())
    else
        let s:ignore = s:ignore + 1
        return a:char
    endif
endfunction
