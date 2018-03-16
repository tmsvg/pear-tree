function! pear_tree#cursor#CharBefore() abort
    return matchstr(getline('.'), '\%' . (col('.') - 1) . 'c.')
endfunction


function! pear_tree#cursor#CharAfter() abort
    return matchstr(getline('.'), '\%' . col('.') . 'c.')
endfunction


function! pear_tree#cursor#TextAfter()
    return getline('.')[(col('.') - 1):]
endfunction


function! pear_tree#cursor#StringAfter() abort
    return matchstr(getline('.')[(col('.') - 1):], '^\S*')
endfunction


function! pear_tree#cursor#OnEmptyLine() abort
    return (col('$') == 1)
endfunction


function! pear_tree#cursor#AtEndOfLine() abort
    return (col('.') == col('$'))
endfunction


function! pear_tree#cursor#SyntaxRegion() abort
    return synIDattr(synIDtrans(synID(line('.'), col('.'), 1)), 'name')
endfunction
