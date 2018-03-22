" Return the length of {str} as it would appear on the screen.
"
" We must account for the difference in string length and string width for
" special characters like <BS> and full-width UNICODE, etc., in order to get
" the number of times <DIRECTION> must be pressed to move over the string.
function! pear_tree#util#VisualStringLength(str) abort
    if strwidth(a:str) >= strlen(a:str)
        return strlen(a:str) - (strwidth(a:str) - strlen(a:str))
    else
        return strchars(a:str)
    endif
endfunction

" Return a list of indices representing positions within {text} at which a
" string in the list {strings} first appears.
function! pear_tree#util#FindAll(text, strings, start)
    let l:indices = []
    for l:string in a:strings
        let l:idx = stridx(a:text, l:string, a:start)
        if l:idx != -1
            call add(l:indices, l:idx)
        endif
    endfor
    return l:indices
endfunction

" Return a list of indices in {text} at which {string} appears.
function! pear_tree#util#FindEvery(text, string, start)
    let l:indices = []
    let l:i = a:start
    while l:i < len(a:text)
        let l:i = stridx(a:text, a:string, l:i + 1)
        if l:i == -1
            break
        endif
        call add(l:indices, l:i)
    endwhile
    return l:indices
endfunction
