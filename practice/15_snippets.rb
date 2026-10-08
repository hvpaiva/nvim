# frozen_string_literal: true

# 15. Completion and snippets. Do each one on a new line (`o`) right below its
# exercise. `:e!` undoes.

# 1. Global snippets, which work in any file. Type `cdate` and accept with
#    `<C-y>`, and today's date goes in. `ctime` gives the time and `cdtm`
#    both.

# 2. Ruby snippets. Type `def` and accept with `<C-y>`, and the method goes in
#    with fields. `<C-l>` goes to the next field and `<C-h>` back. Others to
#    try: there is no `each`, but there are `ea`, `map`, `if`, `ife`, `case`,
#    `class`, `module`, `begin` and `do`.

# 3. Expand right away. Type `ife` and press `<C-j>` instead of waiting for
#    the list, and the snippet expands directly.
#
#    Empty fields show as `•`. `<C-c>`, in Insert mode, ends the snippet and
#    clears the marks. `<Esc>` does not end it, and the marks stay until you
#    go back to Insert mode (`a`) and press `<C-c>`. Reaching the last field
#    with `<C-l>` and leaving to Normal mode also ends it.

# 4. Word completion. Outside the LSP, the list uses the buffer's words. Type
#    `uniq` and watch `unique_identifier` show up.
def words
  unique_identifier = 1
  unique_identifier + 1
end

# 5. `<C-n>` and `<C-p>` move through the list, `<C-y>` accepts and `<C-e>`
#    closes it. `<CR>` never accepts, it always breaks the line. `<M-Space>`
#    (or `<C-x><C-o>`) opens the LSP's list right away and `<C-n>` alone opens
#    the word list.
