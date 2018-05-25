function! pear_tree#insert_mode#GetTraverser() abort
    return copy(s:traverser)
endfunction


function! pear_tree#insert_mode#Ignore(num) abort
    let s:ignore = a:num
endfunction


function! pear_tree#insert_mode#Prepare() abort
    let l:trie = pear_tree#trie#New()
    for l:opener in keys(pear_tree#Pairs())
        call l:trie.Insert(l:opener)
    endfor
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
