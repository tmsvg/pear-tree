Pear Tree
===========
A painless, powerful Vim auto-pair plugin.

Purpose
-------
**Pear Tree** automatically pairs braces, quotes, HTML tags, and many other text items based on a simple-to-define set of rules, and provides pair-wise deletion, newline expansion, and other usual auto-pair features.

Though Pear Tree was originally intended to simply be an easily configurable auto-pairing plugin that wouldn't break undo or dot-repeat, I later found a nice way to allow for the pairing of strings longer than a single character and strings containing wildcard rules. This allows Pear Tree to easily match HTML tags and C-style block comment closers using simple rule definitions.

Installation
------------
Follow the instructions provided by your plugin manager. Using [vim-plug](https://github.com/junegunn/vim-plug), you would place the following in your vimrc and run `:PlugInstall`

```vim
Plug 'tmsvg/pear-tree'
```

Features
--------

### Multi-Character Pair Support

Pear Tree is not limited to pairing single characters like `(` with `)`, `{` with `}`, and so on. If you would like to pair, say, `/*` with `*/` or `<!--` with `-->`, it works just as well.

### Wildcard Support

A powerful feature of Pear Tree is its support for wildcard string matching. This is particularly useful for HTML tags, wherein there can be strings of some arbitrary length between the `<` and `>` characters (e.g. `<body>`, `<ul>`, `<p class="Foo">`).

### Dot-Repeatability

Pear Tree allows brace expansion without breaking Vim's dot-repeat *or* undo functionality. Consider this example:

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

Note that the closing pair disappears after pressing `<CR>`. This is required to not break dot-repeat, but it will be reentered upon `<Plug>(PearTreeFinishExpansion)` (see [Mappings](#mappings)).

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
6      return 1;|
7  }
```

Many implementations of this feature cause the `.` command to only repeat `return 1;` instead of the entire typing sequence.

Usage
-------

### Defining Pairs

Pairs to match globally are defined in the `g:pear_tree_pairs` dictionary variable.

For filetype-specific matching rules, define `b:pear_tree_pairs` in the appropriate file within your ftplugin directory.

Each dictionary item has the following form:

```vim
opener_string: {'closer': closer_string, [options ...]}
```

#### Wildcards

As previously mentioned, Pear Tree supports wildcard matching in string pairs. Wildcards are specified by using an asterisk `*` within the pairs. A wildcard matches user input until the next explicitly defined character in the opener is entered.

A wildcard in the closer is replaced by the string of characters to which the wildcard character in the opener was matched. As an example, with `g:pear_tree_pairs` containing the following rule:

```vim
'<*>': {'closer': '</*>'}
```

Typing `<html>` yields `<html></html>`, `<ul>` yields `<ul></ul>`, and (using an option discussed later to limit characters inserted in the closer) `<p class="Foo">` yields `<p class="Foo"></p>`.

To include a literal asterisk in a rule, you must escape it with a backslash like `\*`. Similarly, to include a literal backslash in a rule, you must escape it with another backslash like `\\`.

#### Options

A Pear Tree rule includes several options to more finely tune its matching behavior.

- `not_in`
    - Form: `'not_in': [syntax region, ...]`,
    - Function: Do not match an opener if the syntax region you are typing in is contained in the list.
    - Example: `'(': {'closer': ')', 'not_in': ['String', 'Comment']}`
    - Notes: This requires syntax to be enabled.

- `not_if`
    - Form: `'not_if': [string, ...]`
    - Function: Do not match an opener that contains a wildcard if the value of that wildcard is contained in the list.
    - Example: `'<*>': {'closer': '</*>', 'not_if': ['br', 'meta']}`

- `until`
    - Form: `'until': regexp pattern`
    - Function: Replace the wildcard character in the closer with the wildcard string in the opener only until the regexp pattern is matched. See `:h match()` for valid patterns.
    - Example: `'<*>': {'closer': '</*>', 'until': '\W'}`
    Typing `<p class="Foo">` yields `<p class="Foo"></p>`, and **not** `<p class="Foo"></p class="Foo">` because the space after `<p` matches the regexp pattern `'\W'`.
    - Notes: Defaults to `'[[:punct:][:space:]]'` (punctuation or space) if not set.

### Mappings

- `<Plug>(PearTreeBackspace)`
    - If cursor is between an opener and closer, delete both. Otherwise, act like typical backspace.
    - Example: `return foo(|)` -> `return foo|`
    - Default mapping: `<BS>`

- `<Plug>(PearTreeExpand)`
    - If cursor is between an opener and closer, add a new line and prepare to add the closer on the line following the cursor's new position.
    - Example:
        ```c
        1  int foo() {|}
        ```
        ->
        ```c
        1  int foo() {
        2      |
        3
        ```
    - Default mapping: `<CR>`

- `<Plug>(PearTreeFinishExpansion)`
    - If `<Plug>PearTreeExpand` has been used, add the closers to their proper positions.
    - Example (continued from above):
        ```c
        1  int foo() {
        2      |
        3
        ```
        ->
        ```c
        1  int foo() {
        2      |
        3  }
        ```
    - Default mapping: `<ESC>`

- `<Plug>(PearTreeJump)`
    - If the cursor is before a closer whose opener appears earlier in the text, move the cursor past the closer.
    - Example:
        ```html
        1  <p class="Foo">Hello, world!|</p>
        ```
        ->
        ```html
        1  <p class="Foo">Hello, world!</p>|
        ```
    - Default mapping: none

- `<Plug>(PearTreeExpandOne)`
    - If `<Plug>(PearTreeExpand)` has been used multiple times, leading to nested pairs, add the innermost closer to its proper position.
    - Example:
        ```html
        1  <html>|</html>
        ```
        First expansion:
        ```html
        1  <html>
        2      <body>|</body>
        3
        ```
        Second expansion:
        ```html
        1  <html>
        2      <body>
        3           <p>Type this and go to the next line.</p>
        4           |
        5
        ```
        ->
        ```html
        1  <html>
        2      <body>
        3           <p>Type this and go to the next line.</p>
        4      </body>|
        5
        ```
    - Default mapping: none


- `<Plug>(PearTreeJNR)`
    - If the cursor is before a closer whose opener appears earlier in the text, move the cursor past the closer and insert a newline ("jump 'n return").
    - Example:
        ```html
        1  <p class="Foo">Hello, world!|</p>
        ```
        ->
        ```html
        1  <p class="Foo">Hello, world!</p>
        2  |
        ```
    - Default mapping: none

### Default Behaviors

Listed here is a summary of default global configurations used by Pear Tree.

```vim
" Default rules for matching:
let g:pear_tree_pairs = {
            \ '(': {'closer': ')'},
            \ '[': {'closer': ']'},
            \ '{': {'closer': '}'},
            \ "'": {'closer': "'"},
            \ '"': {'closer': '"'}
            \ }
" See pear-tree/ftplugin/ for filetype-specific matching rules
```

```vim
" Pear Tree is enabled for all filetypes by default
let g:pear_tree_ft_disabled = []
```

```vim
" Default mappings:
imap <BS> <Plug>(PearTreeBackspace)
imap <CR> <Plug>(PearTreeExpand)
imap <ESC> <Plug>(PearTreeFinishExpansion)

" Not mapped by default:
" <Plug>(PearTreeJump)
" <Plug>(PearTreeExpandOne)
" <Plug>(PearTreeJNR)
```


License
-------

MIT
