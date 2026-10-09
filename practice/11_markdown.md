# 11. Markdown

Only what Markdown does differently from the files before is here. This file
opens with spell checking in English and Portuguese, visual line wrapping and
folding by heading. `:e!` undoes.

## Spell

1. `]s` and `[s` move between the misspelled words below. On one of them,
   `z=` lists suggestions. `zg` adds the word to the English dictionary,
   `2zg` to the Portuguese one and `4zg` to your custom one. `zw` marks it as
   wrong. `<Space>os` turns spell checking on and off.

Esta frase tem um erro de portugues e this sentence has a mistaek.

## Prose wrapping

2. The paragraph below is a single line, shown wrapped on screen. `gqip` (or
   `gwip`) breaks it into lines at the width. In Markdown, `gq` always wraps
   text, never formats.

Neovim keeps the Vim grammar: the operator comes first and the motion or the text object comes after, which is why it composes so well with everything else.

## Words

3. `w` treats `mini-files` as a single word, because `-` is part of a word in
   Markdown. Compare with the same `w` in a Ruby file.

## Links with surround

4. Cursor on `neovim`, `saiwL`, type `https://neovim.io` and `<CR>`, and the
   word becomes a link. Inside the link, `sdL` turns it back into plain text
   and `srLL` changes the address.

The neovim site has the documentation.

## Table

5. Cursor in the table, `gaip|` aligns its columns. `gAip` does it with a
   preview.

| tool | language | role |
|---|---|---|
| neovim | C and Lua | editor |
| standard | Ruby | linter and formatter |

## List

6. Cursor in the list, `vip` and `:sort` sorts it. `!ip sort -r` goes through
   the shell, in reverse order.

- zucchini
- apples
- milk
- bread

## Colors, folds and rendering

7. The colors below show painted (nvim-highlight-colors): #e06c75,
   #98c379, rgb(97, 175, 239).
8. Each heading is a fold. `zc` closes the section under the cursor, `zM`
   closes them all and `zR` opens them all.
9. `<Space>om` renders the Markdown inside the buffer (headings, table,
   checkboxes). Pressing it again turns it off.

- [ ] a task
- [x] a finished one
