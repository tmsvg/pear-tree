" Pear Tree - A painless, powerful Vim auto-pair plugin
" Maintainer: Thomas Savage <thomasesavage@gmail.com>
" Version: 0.8
" License: MIT
" Website: https://github.com/tmsvg/pear-tree


let s:save_cpo = &cpoptions
set cpoptions&vim


" Return {string} with all leading and trailing whitespace removed.
if exists('*trim')
    function! pear_tree#string#Trim(string) abort
        return trim(a:string)
    endfunction
else
    function! pear_tree#string#Trim(string) abort
        return substitute(a:string, '\v^\s*(.{-})\s*$', '\1', '')
    endfunction
endif


" Return the number of times {substring} occurs in {string}.
if v:version > 800 || (v:version == 800 && has('patch794'))
    function! pear_tree#string#Count(string, substring) abort
        return count(a:string, a:substring)
    endfunction
else
    function! pear_tree#string#Count(string, substring) abort
        let l:substr_len = strlen(a:substring)
        if l:substr_len == 0
            return 0
        endif
        return (strlen(a:string) - strlen(substitute(a:string, a:substring, '', 'g'))) / l:substr_len
    endfunction
endif


function! pear_tree#string#EndsWith(string, substring)
    return a:string =~# a:substring . '$'
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
function! pear_tree#string#UnescapedStridx(string, special_char, ...) abort
    let l:start = a:0 ? a:1 : 0
    return index(pear_tree#string#Tokenize(a:string, a:special_char, '__'), '__', l:start)
endfunction


" Return the length of {str} as it would appear on the screen.
"
" Useful for special characters like <BS> and full-width UNICODE, etc., in
" order to get the number of times <DIRECTION> must be pressed to move over
" the string.
function! pear_tree#string#VisualLength(string) abort
    if strwidth(a:string) >= strlen(a:string)
        return strlen(a:string) - (strwidth(a:string) - strlen(a:string))
    else
        return strchars(a:string)
    endif
endfunction


let &cpoptions = s:save_cpo
unlet s:save_cpo
