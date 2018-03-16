function! pear_tree#insert_mode#GetTraverser() abort
    return copy(s:traverser)
endfunction


function! pear_tree#insert_mode#Prepare(trie) abort
    let s:traverser = pear_tree#trie#Traverser(a:trie)
    let s:current_line = line('.')
    let s:current_column = col('.')
endfunction


function! pear_tree#insert_mode#HandleKeypress() abort
    let s:current_column = col('.') + 1
    call s:traverser.StepOrReset(v:char)
endfunction


function! pear_tree#insert_mode#CursorMoved() abort
    let l:new_line = line('.')
    let l:new_col = col('.')
    if l:new_line != s:current_line
        call s:traverser.Reset()
        call s:traverser.TraverseText(getline('.'), 1, l:new_col - 1)
    elseif l:new_col < s:current_column
        while s:current_column > l:new_col
            if s:traverser.AtRoot()
                call s:traverser.TraverseText(getline('.'), 1, l:new_col - 1)
                let s:current_column = l:new_col
                break
            else
                call s:traverser.StepToParent()
            endif
            let s:current_column = s:current_column - 1
        endwhile
    elseif l:new_col > s:current_column
        while s:current_column < l:new_col
            call s:traverser.StepOrReset(pear_tree#cursor#CharBefore())
            let s:current_column = s:current_column + 1
        endwhile
    endif
    let s:current_line = l:new_line
endfunction
