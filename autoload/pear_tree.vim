" Pear Tree - A painless, powerful Vim auto-pair plugin
" Maintainer: Thomas Savage <thomasesavage@gmail.com>
" Version: 0.8
" License: MIT
" Website: https://github.com/tmsvg/pear-tree


let s:save_cpo = &cpoptions
set cpoptions&vim

let s:pear_tree_default_rules = {
            \ 'closer': '',
            \ 'not_in': [],
            \ 'not_if': [],
            \ 'not_like': '',
            \ 'not_at': [],
            \ 'until': '[[:punct:][:space:]]'
            \ }

if v:version > 704 || (v:version == 704 && has('patch849'))
    let s:LEFT = "\<C-g>U\<Left>"
    let s:RIGHT = "\<C-g>U\<Right>"
else
    let s:LEFT = "\<Left>"
    let s:RIGHT = "\<Right>"
endif

if exists('*reltimefloat')
    function! s:TimeElapsed(start_time) abort
        return reltimefloat(reltime(a:start_time)) * 1000
    endfunction
else
    function! s:TimeElapsed(start_time) abort
        return str2float(reltimestr(reltime(a:start_time))) * 1000
    endfunction
endif


function! pear_tree#Pairs() abort
    return get(b:, 'pear_tree_pairs', get(g:, 'pear_tree_pairs'))
endfunction


function! pear_tree#GetOption(option) abort
    let l:var_name = 'pear_tree_' . a:option
    return get(b:, l:var_name, get(g:, l:var_name, 0))
endfunction


function! pear_tree#GetRule(opener, rule) abort
    let l:rules = get(pear_tree#Pairs(), a:opener)
    let l:default = copy(s:pear_tree_default_rules[a:rule])
    if a:rule ==# 'not_at' && pear_tree#IsDumbPair(a:opener)
        call add(l:default, '[a-zA-Z0-9_!?.;]')
    endif
    return get(l:rules, a:rule, l:default)
endfunction


function! pear_tree#IsDumbPair(char) abort
    return has_key(pear_tree#Pairs(), a:char)
                \ && pear_tree#GetRule(a:char, 'closer') ==# a:char
endfunction


function! pear_tree#IsCloser(str) abort
    return index(map(values(pear_tree#Pairs()), 'v:val.closer'), a:str) > -1
endfunction


function! pear_tree#TrimWildcard(opener, wildcard) abort
    let l:until = pear_tree#GetRule(a:opener, 'until')
    if l:until ==# ''
        let l:index = strlen(a:wildcard)
    else
        let l:index = match(a:wildcard, l:until)
        if l:index == 0
            return ''
        endif
    endif
    return a:wildcard[:max([-1, l:index - 1])]
endfunction


function! pear_tree#GenerateCloser(opener, wildcard, position) abort
    if !has_key(pear_tree#Pairs(), a:opener)
        return ''
    endif
    let l:not_in = pear_tree#GetRule(a:opener, 'not_in')
    if a:position[0] > 0 && l:not_in != []
        if pear_tree#buffer#SyntaxRegion(a:position) =~? join(l:not_in, '\|')
            return ''
        endif
    endif
    let l:closer = pear_tree#GetRule(a:opener, 'closer')
    if a:wildcard ==# ''
        return pear_tree#string#Encode(l:closer, '*', '')
    endif
    let l:trimmed_wildcard = pear_tree#TrimWildcard(a:opener, a:wildcard)
    if l:trimmed_wildcard ==# ''
        return ''
    endif
    if index(pear_tree#GetRule(a:opener, 'not_if'), l:trimmed_wildcard) > -1
        return ''
    endif
    let l:not_like = pear_tree#GetRule(a:opener, 'not_like')
    if l:not_like !=# '' && match(a:wildcard, l:not_like) > -1
        return ''
    endif
    " Replace unescaped * chars with the wildcard string.
    return pear_tree#string#Encode(l:closer, '*', l:trimmed_wildcard)
endfunction


" Check if {opener} is balanced in the buffer. If it is, return the position
" of the final character of the opener that balances the pair. If the pair is
" unbalanced, return [-1, -1].
"
" An optional argument {skip_count} tells the function to ignore the first
" {skip_count} openers. This can be used to see if the closer at {start}
" would be balanced if the previous {skip_count} openers were deleted.
"
" An optional argument {timeout_length} tells the function to exit after the
" given amount of time has passed. If it times out, return [0, 0].
" Note that this argument requires Vim to be compiled with +reltime support.
"
" An optional argument {cursor_at_opener} tells the function that the user is
" currently typing an opener. So if the buffer looks like:
"       <html|
"         <body></body>
" the function will ignore <html instead of considering it to be an opener
" `<*>` whose wildcard string is `html   <body`.
function! pear_tree#IsBalancedPair(opener, wildcard, start, ...) abort
    let l:count = a:0 ? a:1 : 0

    let l:timeout_length = a:0 >= 2 ? a:2 : 0
    if l:timeout_length > 0
        let l:start_time = reltime()
    endif

    let l:cursor_at_opener = a:0 >= 3 ? a:3 : 0

    let l:not_in = pear_tree#GetRule(a:opener, 'not_in')
    " The syntax region at {start} should always be included in searches.
    call filter(l:not_in, 'pear_tree#buffer#SyntaxRegion(a:start) !~? v:val')

    " Generate a hint to find openers faster. Since {wildcard} is obtained
    " from the closer, it might be a trimmed version of the opener's.
    let l:idx = pear_tree#string#UnescapedStridx(a:opener, '*')
    let l:opener_hint = pear_tree#string#Encode(a:opener[:(l:idx)], '*', a:wildcard)

    let l:closer = pear_tree#GenerateCloser(a:opener, a:wildcard, a:start)
    if l:closer ==# ''
        return a:start
    endif
    let l:closer_offset = strlen(l:closer) - 1

    let l:has_wildcard = (l:idx != -1)
    let l:is_dumb = pear_tree#IsDumbPair(l:closer)

    if l:has_wildcard
        let l:trie = pear_tree#trie#New(keys(pear_tree#Pairs()))
        let l:traverser = pear_tree#trie_traverser#New(l:trie)
    endif

    let l:current_pos = [a:start[0], a:start[1]]
    let l:closer_pos = [a:start[0], a:start[1] + 1]
    let l:opener_pos = [a:start[0], a:start[1] + 1]
    while l:current_pos[0] > -1
        if l:timeout_length > 0
                    \ && s:TimeElapsed(l:start_time) >= l:timeout_length
            return [0, 0]
        endif
        " Find the previous opener and closer in the buffer.
        if pear_tree#buffer#ComparePositions(l:opener_pos, l:current_pos) > 0
            if l:has_wildcard
                let l:search_pos = copy(l:current_pos)
                while l:search_pos[0] > -1
                    call l:traverser.Reset()
                    let l:search_pos = pear_tree#buffer#ReverseSearch(l:opener_hint, l:search_pos)
                    let l:end_pos = l:traverser.WeakTraverseBuffer(l:search_pos, l:opener_pos)
                    if l:cursor_at_opener
                                \ && pear_tree#buffer#ComparePositions(l:search_pos, pear_tree#cursor#Position()) < 0
                                \ && pear_tree#buffer#ComparePositions(l:end_pos, pear_tree#cursor#Position()) > 0
                        " Ignore this opener.
                    elseif l:end_pos[0] != -1
                                \ && pear_tree#GenerateCloser(l:traverser.GetString(), l:traverser.GetWildcardString(), [0, 0]) ==# l:closer
                        break
                    endif
                    let l:search_pos[1] = l:search_pos[1] - 1
                endwhile
                let l:opener_pos = l:end_pos
            else
                let l:opener_pos = pear_tree#buffer#ReverseSearch(l:opener_hint,
                                                                \ l:current_pos,
                                                                \ l:not_in)
            endif
        endif
        if pear_tree#buffer#ComparePositions(l:closer_pos, l:current_pos) > 0
            let l:closer_pos = pear_tree#buffer#ReverseSearch(l:closer,
                                                            \ l:current_pos,
                                                            \ l:not_in)
        endif
        if l:closer_pos[0] != -1
                    \ && pear_tree#buffer#ComparePositions([l:closer_pos[0], l:closer_pos[1] + l:closer_offset], l:opener_pos) >= 0
            let l:count = l:count + 1
            " It's not feasible to determine if dumb pairs are balanced in the
            " buffer, so leave early at this point.
            if l:is_dumb
                if l:has_wildcard
                    return l:opener_pos
                " Ensure that the opener doesn't overlap the starting position.
                elseif l:opener_pos[0] != a:start[0]
                            \ || abs(a:start[1] - l:opener_pos[1]) >= strlen(a:opener)
                    let l:opener_pos[1] += strlen(a:opener) - 1
                    return l:opener_pos
                endif
            endif
            let l:current_pos = [l:closer_pos[0], l:closer_pos[1] - 1]
        elseif l:opener_pos[0] != -1 && l:count != 0
            let l:count = l:count - 1
            if l:count == 0
                if !l:has_wildcard
                    let l:opener_pos[1] += strlen(l:opener_hint) - 1
                endif
                return l:opener_pos
            endif
            let l:current_pos = [l:opener_pos[0], l:opener_pos[1] - 1]
        else
            return [-1, -1]
        endif
    endwhile
    return [-1, -1]
endfunction


" Return the opener and closer that surround the cursor, as well as the
" wildcard string and the position of the opener.
function! pear_tree#GetSurroundingPair() abort
    let l:pairs = pear_tree#Pairs()
    let l:closers = map(values(l:pairs), 'v:val.closer')
    let l:closer_trie = pear_tree#trie#New(l:closers)
    let l:closer_traverser = pear_tree#trie_traverser#New(l:closer_trie)
    let l:col = matchend(getline('.'), '\s\+', col('.') - 1)
    if l:col == -1
        let l:col = col('.') - 1
    endif
    let l:start = [line('.'), l:col]
    let l:end = pear_tree#buffer#End()
    if l:closer_traverser.WeakTraverseBuffer(l:start, l:end) == [-1, -1]
        return []
    endif

    let l:closer = l:closer_traverser.GetString()
    let l:wildcard = l:closer_traverser.GetWildcardString()
    for l:opener in keys(filter(copy(l:pairs), 'v:val.closer ==# l:closer'))
        let l:pos = pear_tree#IsBalancedPair(l:opener, l:wildcard, l:start)
        if l:pos[0] != -1 && pear_tree#buffer#ComparePositions(l:pos, l:start) < 0
            return [l:opener, l:closer, l:wildcard, l:pos]
        endif
    endfor
    return []
endfunction

" Return the position of the end of the innermost pair that surrounds {start}.
"
" An option argument {timeout_length} tells the function to exit early after
" the given amount of time has passed. If it times out, return [0, 0].
" Note that this argument requires Vim to be compiled with +reltime support.
function! pear_tree#GetOuterPair(opener, closer, start, ...) abort
    if pear_tree#buffer#ComparePositions(a:start, [1, 0]) < 0
        return [-1, -1]
    endif
    let l:timeout_length = a:0 ? a:1 : 0
    if l:timeout_length > 0
        let l:start_time = reltime()
    endif

    let l:not_in = pear_tree#GetRule(a:opener, 'not_in')
    let l:opener_pos = pear_tree#buffer#Search(a:opener, a:start, l:not_in)
    let l:closer_pos = pear_tree#buffer#Search(a:closer, a:start, l:not_in)
    while l:opener_pos != [-1, -1]
                \ && pear_tree#buffer#ComparePositions(l:opener_pos, l:closer_pos) < 0
        if l:timeout_length > 0
                    \ && s:TimeElapsed(l:start_time) >= l:timeout_length
            return [0, 0]
        endif
        let l:opener_pos[1] += 1
        let l:closer_pos[1] += 1
        let l:opener_pos = pear_tree#buffer#Search(a:opener, l:opener_pos, l:not_in)
        let l:closer_pos = pear_tree#buffer#Search(a:closer, l:closer_pos, l:not_in)
    endwhile
    if l:opener_pos == [-1, -1]
        let l:opener_pos = pear_tree#buffer#End()
    endif
    let l:closer_pos = pear_tree#buffer#ReverseSearch(a:closer, l:opener_pos, l:not_in)
    if pear_tree#buffer#ComparePositions(l:closer_pos, a:start) < 0
        let l:closer_pos = [-1, -1]
    endif
    return l:closer_pos
endfunction


" Return the position of the end of the innermost wildcard pair that surrounds
" {start}. Note that {wildcard} must be the wildcard string as it appears in
" {closer}, after the `until` rule has been applied.
"
" An option argument {timeout_length} tells the function to exit early after
" the given amount of time has passed. If it times out, return [0, 0].
" Note that this argument requires Vim to be compiled with +reltime support.
function! pear_tree#GetOuterWildcardPair(opener, closer, wildcard, start, ...) abort
    if pear_tree#buffer#ComparePositions(a:start, [1, 0]) < 0
        return [-1, -1]
    endif
    let l:timeout_length = a:0 ? a:1 : 0
    if l:timeout_length > 0
        let l:start_time = reltime()
    endif

    let l:not_in = pear_tree#GetRule(a:opener, 'not_in')
    let l:traverser = deepcopy(b:pear_tree_traverser)
    let l:idx = pear_tree#string#UnescapedStridx(a:opener, '*')
    let l:opener_hint = pear_tree#string#Encode(a:opener[:(l:idx)], '*', a:wildcard)

    let l:opener_pos = pear_tree#buffer#Search(l:opener_hint, a:start)
    let l:closer_pos = pear_tree#buffer#Search(a:closer, a:start, l:not_in)
    let l:end = pear_tree#buffer#End()
    while l:opener_pos != [-1, -1]
                \ && (pear_tree#buffer#ComparePositions(l:opener_pos, l:closer_pos) < 0
                    \ || l:traverser.WeakTraverseBuffer(l:opener_pos, l:end) == [-1, -1]
                    \ || pear_tree#GenerateCloser(l:traverser.GetString(), a:wildcard, [0, 0]) !=# a:closer)
        if l:timeout_length > 0 && s:TimeElapsed(l:start_time) >= l:timeout_length
            return [0, 0]
        endif
        let l:opener_pos[1] += 1
        let l:opener_pos = pear_tree#buffer#Search(l:opener_hint, l:opener_pos)
        if pear_tree#buffer#ComparePositions(l:opener_pos, l:closer_pos) > 0
            let l:closer_pos[1] += 1
            let l:closer_pos = pear_tree#buffer#Search(a:closer, l:closer_pos, l:not_in)
        endif
    endwhile
    if l:opener_pos == [-1, -1]
        let l:opener_pos = l:end
    endif
    let l:closer_pos = pear_tree#buffer#ReverseSearch(a:closer, l:opener_pos, l:not_in)
    if pear_tree#buffer#ComparePositions(l:closer_pos, a:start) < 0
        let l:closer_pos = [-1, -1]
    endif
    return l:closer_pos
endfunction


let &cpoptions = s:save_cpo
unlet s:save_cpo
