Pear Tree
=========
A painless, powerful Vim auto-pair plugin.

Purpose
-------
**Pear Tree** automatically pairs parentheses, quotes, HTML tags, and many
other text items based on a simple-to-define set of rules. It also provides
pair-wise deletion, newline expansion, and other typical auto-pair features
without interfering with Vim's undo or dot-repeat functionality.

Installation
------------
Follow the instructions provided by your plugin manager. Using
[vim-plug](https://github.com/junegunn/vim-plug), you would place the
following in your vimrc and run `:PlugInstall`

```vim
Plug 'tmsvg/pear-tree'
```

You can also install Pear Tree manually by placing the files in their
appropriate locations in your Vim directory. Remember to run `:helptags` if
you choose this method.

Features
--------
### Multi-Character Pair Support

Pear Tree is not limited to pairing single characters like `(` with `)`, `{`
with `}`, and so on. If you would like to pair, say, `/*` with `*/` or `<!--`
with `-->`, simply add them to your `g:pear_tree_pairs` and it will work just
as well.

### Wildcard Support

A powerful feature of Pear Tree is its support for wildcard string matching.
This is particularly useful for HTML tags, wherein there can be strings of
some arbitrary length between the `<` and `>` characters (e.g. `<body>`,
`<ul>`, `<p class="Foo">`).

### Dot-Repeatability

Pear Tree allows brace expansion without breaking Vim's dot-repeat *or* undo
functionality. Consider this example:

```c
1  int foo();|
2
3  int bar();
```

Type `<BS> {`

```c
1  int foo() {|}
2
3  int bar();
```

Type `<CR>`:

```c
1  int foo() {
2      |
3
4
5  int bar();
```

Note that the closing pair disappears after pressing `<CR>`. This is required
to not break dot-repeat, but it will be automatically restored later.

Next, type `return 1;` and leave insert mode:

```c
1  int foo() {
2      return 1;
3  }
4
5  int bar();
```

Finally, move to line 5 and use the `.` command:

```c
1  int foo() {
2      return 1;
3  }
4
5  int bar() {
6      return 1;
7  }|
```

Many implementations of this feature cause the `.` command to only repeat
`return 1;` instead of the entire typing sequence.

However, if you would prefer expansion to behave like other plugins and text
editors, you can prevent Pear Tree from erasing the closing string by setting
`g:pear_tree_repeatable_expand` to `0`.

### Smart Pairing

Pear Tree includes options to intelligently decide when an opening string
should be closed, when typing a closing character should move the cursor past
an existing closer, and when both characters in a pair should be deleted when
pressing backspace. If these options are enabled, Pear Tree will examine the
balance of existing pairs to decide what action should be taken. It will choose
the action that makes nearby pairs properly balanced, as summarized in the
following table:

|           | Before        | After (smart pairing) | After (no smart pairing)
| --------- | ------------- | --------------------- | ------------------------ |
| Opener    | `foo(bar\|))` | `foo(bar(\|))`        | `foo(bar(\|)))`          |
| Closer    | `foo(bar(\|)` | `foo(bar()\|)`        | `foo(bar()\|`            |
| Backspace | `foo((\|)`    | `foo(\|)`             | `foo(\|`                 |

Smart pairs must be [enabled manually](#defaults).

Usage
-----
Pear Tree's primary features are enabled automatically, but some useful options
and mappings must be set manually. Please read `:help pear-tree` for useful
information on how to define your own pairs, use wildcards, customize mappings,
and more.

### Defaults

**Note:** The following code is only here to summarize the available options
and show what Pear Tree sets them to by default. You only need to copy it to
your config if you intend to change values of the variables or key mappings.

```vim
" Default rules for matching:
let g:pear_tree_pairs = {
            \ '(': {'closer': ')'},
            \ '[': {'closer': ']'},
            \ '{': {'closer': '}'},
            \ "'": {'closer': "'"},
            \ '"': {'closer': '"'}
            \ }
" See pear-tree/after/ftplugin/ for filetype-specific matching rules

" Pear Tree is enabled for all filetypes by default:
let g:pear_tree_ft_disabled = []

" Pair expansion is dot-repeatable by default:
let g:pear_tree_repeatable_expand = 1

" Smart pairs are disabled by default:
let g:pear_tree_smart_openers = 0
let g:pear_tree_smart_closers = 0
let g:pear_tree_smart_backspace = 0

" If enabled, smart pair functions timeout after 60ms:
let g:pear_tree_timeout = 60

" Automatically map <BS>, <CR>, and <Esc>
let g:pear_tree_map_special_keys = 1

" Default mappings:
imap <BS> <Plug>(PearTreeBackspace)
imap <CR> <Plug>(PearTreeExpand)
imap <Esc> <Plug>(PearTreeFinishExpansion)
" Pear Tree also makes <Plug> mappings for each opening and closing string.
"     :help <Plug>(PearTreeOpener)
"     :help <Plug>(PearTreeCloser)

" Not mapped by default:
" <Plug>(PearTreeSpace)
" <Plug>(PearTreeJump)
" <Plug>(PearTreeExpandOne)
" <Plug>(PearTreeJNR)
```

License
-------
MIT
