function! pear_tree#cursor#Position()
    return [line('.'), col('.')]
endfunction


function! pear_tree#cursor#PrevChar() abort
    return matchstr(getline('.'), '\%' . (col('.') - 1) . 'c.')
endfunction


function! pear_tree#cursor#NextChar() abort
    return matchstr(getline('.'), '\%' . col('.') . 'c.')
endfunction


function! pear_tree#cursor#TextBefore()
    return getline('.')[:(col('.') - 2)]
endfunction


function! pear_tree#cursor#TextAfter()
    return getline('.')[(col('.') - 1):]
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
