" Return the length of a:str as it would appear on the screen.
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
