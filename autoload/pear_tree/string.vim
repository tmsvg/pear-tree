" Return {string} with all leading a trailing whitespace removed.
function! pear_tree#string#Trim(string) abort
    let l:start = 0
    let l:end = strlen(a:string)
    while l:start < l:end && a:string[l:start] <=# ' '
        let l:start = l:start + 1
    endwhile
    while l:start < l:end && a:string[l:end - 1] <=# ' '
        let l:end = l:end - 1
    endwhile
    return a:string[(l:start):(l:end - 1)]
endfunction


" Return {string} with all occurrences of {special_char} escaped and all
" occurrences of {replacement} replaced with unescaped {special_char}.
function! pear_tree#string#Decode(string, special_char, replacement) abort
    return substitute(escape(a:string, a:special_char . '\\'), a:replacement, a:special_char, 'g')
endfunction


" Return a list that consists of characters in {string} with all unescaped
" occurrences of {special_char} replaced with {replacement} and all escaped
" occurrences of {special_char} unescaped.
function! pear_tree#string#Tokenize(string, special_char, replacement) abort
    let l:is_esc = 0
    let l:tokens = []
    for l:ch in split(a:string, '\zs')
        if l:is_esc
            call add(l:tokens, l:ch)
            let l:is_esc = 0
        elseif l:ch ==# a:special_char
            call add(l:tokens, a:replacement)
        elseif l:ch ==# '\'
            let l:is_esc = 1
        else
            call add(l:tokens, l:ch)
        endif
    endfor
    return l:tokens
endfunction


" Return {string} with all unescaped occurrences of {special_char} replaced
" with {replacement} and all escaped occurrences of {special_char} unescaped.
function! pear_tree#string#Encode(string, special_char, replacement) abort
    return join(pear_tree#string#Tokenize(a:string, a:special_char, a:replacement), '')
endfunction


" Return the index of the first unescaped occurrence of {special_char} in
" {string}, with the search starting at {start}.
function! pear_tree#string#UnescapedStridx(string, special_char, ...)
    let l:start = a:0 ? a:1 : 0
    return index(pear_tree#string#Tokenize(a:string, a:special_char, '__'), '__', l:start)
endfunction


" Return the length of {str} as it would appear on the screen.
"
" Useful for special characters like <BS> and full-width UNICODE, etc., in
" order to get the number of times <DIRECTION> must be pressed to move over
" the string.
function! pear_tree#string#VisualLength(str) abort
    if strwidth(a:str) >= strlen(a:str)
        return strlen(a:str) - (strwidth(a:str) - strlen(a:str))
    else
        return strchars(a:str)
    endif
endfunction


" Return a list of indices representing positions within {text} at which a
" string in the list {strings} first appears.
function! pear_tree#string#FindAll(text, strings, start)
    let l:indices = []
    for l:string in a:strings
        let l:idx = stridx(a:text, l:string, a:start)
        if l:idx != -1
            call add(l:indices, l:idx)
        endif
    endfor
    return l:indices
endfunction
