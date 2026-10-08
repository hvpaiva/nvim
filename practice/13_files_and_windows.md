# 13. Files, search, windows and sessions

This file has nothing to edit. The targets are the other files.

## Oil

1. `-` opens this file's directory as a buffer. `<CR>` enters, `-` goes up,
   and `_` opens the working directory, as does `<Space>ed`.
2. Edit files as text. In Oil, on a new line (`o`), type `draft.rb` and `:w`,
   and the file is created. Change a name on a line and `:w` renames it. `dd`
   on a line and `:w` deletes it (it asks for confirmation).
3. `<C-p>` previews the file under the cursor, `<C-s>` opens it in a vertical
   split, `g.` shows hidden files and `g?` lists all the keys.

## Pickers (mini.pick)

4. `<Space>ff` finds files, `<Space>fg` searches text live and `<Space>fG`
   searches the word under the cursor. `<Space>fb` lists buffers and
   `<Space>fr` reopens the last picker.
5. Inside any picker, `<C-n>` / `<C-p>` move, `<Tab>` toggles the preview,
   and `<C-s>`, `<C-v>` and `<C-t>` open in a split, a vsplit and a tab.
   `<C-y>` refines, freezing the current result and starting a new search
   inside it (`<M-Space>` does the same with the marked items only).
   mini.pick's default is `<C-Space>`, which herdr uses as its prefix.
6. Search and replace across the project. `<Space>fg`, type `Item`, `<C-a>`
   marks everything and `<C-q>` sends the marked items to the quickfix (the
   default `<M-CR>` is herdr's split).
7. Other pickers are `<Space>fh` (help), `<Space>fk` (keymaps), `<Space>fl`
   and `<Space>fL` (lines of all buffers and of this one), `<Space>f/` and
   `<Space>f:` (search and command history) and `<Space>ft` (TODOs in the
   quickfix).

## Editable quickfix

8. With the quickfix from step 6 open (`<Space>eq` opens and closes it),
   change `Item` to `Product` right in the list's lines and `:w`, and the
   change goes to the files. `>` shows context around each line and `<` hides
   it. `]q` and `[q` move through the items without opening the list.
   `<Space>eQ` is the location list.
9. The other way is `:cdo s/Item/Product/g | update`.

## Buffers and windows

10. `]b` and `[b` move through buffers, `<Space>ba` goes back to the previous
    one, `<Space>bd` closes the buffer without closing the window and
    `<Space>bs` opens a throwaway scratch buffer.
11. `]f` and `[f` go to the neighboring file in the directory, `]o` and `[o`
    move through recently opened files.
12. `<C-w>v` splits vertically. Press `<C-w>` and wait, and mini.clue shows
    the resize mode, where `+`, `-`, `<` and `>` repeat without pressing
    `<C-w>` again. `<Space>oz` zooms the current window and, pressed again,
    undoes it. `]w` and `[w` move between windows.

## Sessions and visits

13. `<Space>sn` saves a named session, `<Space>sr` opens one, `<Space>sw`
    overwrites the current one and `<Space>sd` deletes one. `<Space>sR`
    restarts nvim keeping the session.
14. `<Space>fv` lists the files you visit the most. `<Space>vv` marks the
    current file as core and `<Space>vC` lists only this project's core
    files. `<Space>vl` adds a label with another name.

## Other

15. `<Space>en` shows the notification history.
16. Type `:W` and `<CR>`, and mini.cmdline corrects it to `:w`. The command
    line also completes as you type.
17. `<Space>oR` restarts nvim and `:PackUpdate` updates the plugins.
18. When you reopen a file, the cursor goes back to where it was, and the
    working directory follows the project root of the open file.
