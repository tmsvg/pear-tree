function! pear_tree#insert_mode#GetTraverser() abort
    return copy(s:traverser)
endfunction


function! pear_tree#insert_mode#Ignore(length) abort
    let s:ignore_chars = a:length
endfunction


function! pear_tree#insert_mode#Prepare(trie) abort
    let s:traverser = pear_tree#trie#Traverser(a:trie)
endfunction


function! pear_tree#insert_mode#Enter() abort
    let s:current_line = line('.')
    let s:current_column = col('.')
    let s:chars_inserted = 0
    let s:ignore_chars = 0
    let s:column_started_insert = s:current_column
    call s:traverser.Reset()
    call s:traverser.TraverseText(getline('.'), 1, s:current_column - 1)
endfunction


function! pear_tree#insert_mode#HandleKeypress() abort
    let s:chars_inserted = s:chars_inserted + 1 - s:ignore_chars
    let s:ignore_chars = 0
    let s:current_column = col('.') + 1
    call s:traverser.StepOrReset(v:char)
endfunction


function! pear_tree#insert_mode#CursorMoved() abort
    let l:new_line = line('.')
    let l:new_col = col('.')
    if s:chars_inserted == 0
        if l:new_line != s:current_line
            call s:traverser.Reset()
            call s:traverser.TraverseText(getline('.'), 1, l:new_col - 1)
        elseif l:new_col == s:current_column - 1
            call s:traverser.StepToParent()
        elseif l:new_col == s:current_column + 1
            call s:traverser.StepOrReset(pear_tree#cursor#CharBefore())
        endif
    elseif s:chars_inserted > 1
        " The event missed some input text. This was probably due to the
        " pop-up menu being open (see :h CursorMovedI).
        if !s:traverser.AtRoot()
            call s:traverser.Reset()
            call s:traverser.TraverseText(getline('.'), s:column_started_insert, l:new_col - 1)
        endif
    endif
    let s:chars_inserted = 0
    let s:current_column = l:new_col
    let s:current_line = l:new_line
endfunction
