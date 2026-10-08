# 11. Markdown

Only what Markdown does differently from the files before is here. This file
opens with spell checking in English and Portuguese and folding by heading.
`:e!` undoes.

## Spell

1. `]s` and `[s` move between the misspelled words below. On one of them,
   `z=` lists suggestions. `zg` adds the word to the English dictionary,
   `2zg` to the Portuguese one and `4zg` to your custom one. `zw` marks it as
   wrong. `<Space>os` turns spell checking on and off.

Esta frase tem um erro de portugues e this sentence has a mistaek.

## Words

2. `w` treats `mini-files` as a single word, because `-` is part of a word in
   Markdown. Compare with the same `w` in a Ruby file.

## Links with surround

3. Cursor on `neovim`, `saiwL`, type `https://neovim.io` and `<CR>`, and the
   word becomes a link. Inside the link, `sdL` turns it back into plain text
   and `srLL` changes the address.

The neovim site has the documentation.

## List

4. Cursor in the list, `vip` and `:sort` sorts it. `!ip sort -r` goes through
   the shell, in reverse order.

- zucchini
- apples
- milk
- bread

## Colors, folds and rendering

5. The colors below show painted (nvim-highlight-colors): #e06c75,
   #98c379, rgb(97, 175, 239).
6. Each heading is a fold. `zc` closes the section under the cursor, `zM`
   closes them all and `zR` opens them all.
7. `<Space>om` renders the Markdown inside the buffer (headings, lists,
   checkboxes). Pressing it again turns it off.

- [ ] a task
- [x] a finished one
