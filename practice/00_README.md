# Neovim in practice (your config)

Each file is one subject. Inside it, each exercise is a short comment with the
keys, right above the code you apply them to. Keys are practiced once, so the
Markdown and shell files hold only what those languages do differently. Go
through the files in order, opening each one with `<Space>ff`.

| File | Subject |
|---|---|
| `01_motions.rb` | relative numbers, mini.jump, mini.jump2d, marks, jumplist, mini.bracketed, methods and classes |
| `02_textobjects.rb` | mini.ai (F, c, o, q, b, a, f, ?, N, l, g[ g]), incremental selection, `<Space>y` |
| `03_editing.rb` | `.`, `cgn`, `<Space>S`, `:s` with preview, `:g`, macros, visual block, mini.move, registers, undotree |
| `04_surround.rb` | mini.surround, treesj's `gS`, mini.align, mini.comment, mini.pairs |
| `05_csv.txt` | the same transformation three ways (`:s`, macro, `:norm`) |
| `06_lsp.rb` | hover, definition, types, references, rename, code actions, symbols, inlay hints, completion, on-type edits |
| `07_lint_format.rb` | diagnostics, `gQ`, `gq`, `gw`, `gra` quick fixes |
| `08_syntax.rb` | live syntax errors |
| `lib/calculator.rb` + `test/calculator_test.rb` | vim-test, alternate files, test code lenses, debugging with rdbg |
| `10_repl.rb` | irb on the side, sending a line, a paragraph and a selection |
| `11_markdown.md` | spell, prose wrapping, words with `-`, links with surround, tables, sorting, colors, folds by heading, rendering |
| `12_shell.sh` | jq and awk highlighted inside shell, automatic chmod |
| `13_files_and_windows.md` | Oil, pickers, editable quickfix, buffers, windows, sessions, visits |
| `14_git.md` | Fugitive, mini.diff, hunks, git pickers |
| `15_snippets.rb` | completion, global and Ruby snippets |
| `16_training.md` | hardtime, precognition, training games |

## Back to the original

`:e!` discards the buffer's changes. Once saved, `:Practice!` replaces these
files with a fresh copy, git repository included, and everything changed here
is lost.

The files are a copy of `practice/` in the config repository, kept in
`~/.local/state/nvim/practice`. An exercise is fixed there, and `:Practice!`
brings the fix here.

## Finding things on your own

Press `<Space>` and wait, and mini.clue shows the groups (`b` buffer, `e`
explore, `f` find, `g` git, `i` REPL, `o` other, `p` training, `r` debug, `s`
session, `t` test, `v` visits, `y` yank). The same goes for `g`, `[`, `]`, `z`,
`s`, `"`, `'`, `` ` ``, `<C-w>` and, in Insert mode, `<C-r>`. `<Space>fk` finds
any keymap by name.

Hardtime is on, so repeating `h`, `j`, `k` or `l` more than three times in a
row is blocked and it suggests a better motion. `<Space>pd` turns it on and
off.
